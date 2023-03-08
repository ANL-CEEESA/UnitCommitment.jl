# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using JuMP

"""
    function compute_lmp(
        model::JuMP.Model,
        method::LMP.Method;
        optimizer = nothing
    )

Calculates the locational marginal prices of the given unit commitment instance.
Returns a dictionary of LMPs. Each key is usually a tuple of "Bus name" and time index.
Returns nothing if there is an error in solving the LMPs.

Arguments
---------

- `model`:
    the UnitCommitment model, must be solved before calling this function.

- `method`:
    the LMP method, must be specified.

- `optimizer`:
    the optimizer for solving the LP problem.

Examples
--------

```julia

using UnitCommitment
using Cbc
using HiGHS

import UnitCommitment:
    LMP
    
# Read benchmark instance
instance = UnitCommitment.read("instance.json")

# Construct model (using state-of-the-art defaults)
model = UnitCommitment.build_model(
    instance = instance,
    optimizer = Cbc.Optimizer,
)

# Get the LMPs before solving the UC model
# Error messages will be displayed and the returned value is nothing.
# lmp = UnitCommitment.compute_lmp(model, LMP.Method(), optimizer = HiGHS.Optimizer) # DO NOT RUN

UnitCommitment.optimize!(model)

# Get the LMPs after solving the UC model (the correct way)
# DO NOT use Cbc as the optimizer here. Cbc does not support dual values.
# Compute regular LMP
my_lmp = UnitCommitment.compute_lmp(
    model,
    LMP.Method(),
    optimizer = HiGHS.Optimizer,
)

# Accessing the 'my_lmp' dictionary
# Example: "b1" is the bus name, 1 is the first time slot
@show my_lmp["b1", 1]

```

"""

function compute_lmp(
    model::JuMP.Model,
    method::LMP.Method;
    optimizer = nothing
)
    # Error if a linear optimizer is not specified
    if isnothing(optimizer)
        @error "Please supply a linear optimizer."
        return nothing
    end

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