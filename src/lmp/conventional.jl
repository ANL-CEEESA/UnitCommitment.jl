# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using JuMP

"""
    function compute_lmp(
        model::JuMP.Model,
        method::ConventionalLMP;
        optimizer,
    )::OrderedDict{Tuple{String,Int},Float64}

Calculates conventional locational marginal prices of the given unit commitment
instance. Returns a dictionary mapping `(bus_name, time)` to the marginal price.

Arguments
---------

- `model`:
    the UnitCommitment model, must be solved before calling this function.

- `method`:
    the LMP method.

- `optimizer`:
    the optimizer for solving the LP problem.

Examples
--------

```julia
using UnitCommitment
using HiGHS

import UnitCommitment: ConventionalLMP

# Read benchmark instance
instance = UnitCommitment.read_benchmark("matpower/case118/2018-01-01")

# Build the model
model = UnitCommitment.build_model(
    instance = instance,
    optimizer = HiGHS.Optimizer,
)

# Optimize the model
UnitCommitment.optimize!(model)

# Compute the LMPs using the conventional method
lmp = UnitCommitment.compute_lmp(
    model,
    ConventionalLMP(),
    optimizer = HiGHS.Optimizer,
)

# Access the LMPs
# Example: "b1" is the bus name, 1 is the first time slot
@show lmp["b1", 1]
```
"""
function compute_lmp(
    model::JuMP.Model,
    ::ConventionalLMP;
    optimizer,
)::OrderedDict{Tuple{String,Int},Float64}
    # Validate model, the UC model must be solved beforehand
    if !has_values(model)
        @error "The UC model must be solved before calculating the LMPs."
        @error "The LMPs are NOT calculated."
        return nothing
    end

    # Prepare the LMP result dictionary
    lmp = OrderedDict()

    # Calculate LMPs
    # Fix all binary variables to their optimal values and relax integrality
    @info "Calculating LMPs..."
    @info "Fixing all binary variables to their optimal values and relax integrality."
    vals = Dict(v => value(v) for v in all_variables(model))
    for v in all_variables(model)
        if is_binary(v)
            unset_binary(v)
            fix(v, vals[v])
        end
    end
    # fix!(model, model[:solution])
    relax_integrality(model)
    set_optimizer(model, optimizer)

    # Solve the LP
    @info "Solving the LP..."
    JuMP.optimize!(model)
    
    # Obtain dual values (LMPs) and store into the LMP dictionary
    @info "Getting dual values (LMPs)..."
    for (key, val) in model[:eq_net_injection]
        lmp[key] = dual(val)
    end

    # Return the LMP dictionary
    @info "Calculation completed."
    return lmp
end