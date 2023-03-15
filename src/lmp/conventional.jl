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
    if !has_values(model)
        error("The UC model must be solved before calculating the LMPs.")
    end
    lmp = OrderedDict()

    @info "Fixing binary variables and relaxing integrality..."
    vals = Dict(v => value(v) for v in all_variables(model))
    for v in all_variables(model)
        if is_binary(v)
            unset_binary(v)
            fix(v, vals[v])
        end
    end
    relax_integrality(model)
    set_optimizer(model, optimizer)

    @info "Solving the LP..."
    JuMP.optimize!(model)
    
    @info "Getting dual values (LMPs)..."
    for (key, val) in model[:eq_net_injection]
        lmp[key] = dual(val)
    end

    return lmp
end
