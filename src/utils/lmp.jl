# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using JuMP, Clp

"""
    function get_lmp(
        model::JuMP.Model; 
        optimizer = nothing,
        verbose::Bool=true
    )

Calculates the locational marginal prices of the given unit commitment instance.
Returns a dictionary of LMPs. Each key is usually a tuple of "Bus name" and time index.
Returns false if there is an error in solving the LMPs.

Arguments
---------

- `model`:
    the UnitCommitment model, must be solved before calling this function.

- `optimizer`:
    the optimizer for solving the LP problem. If not specified, the method will use Clp.

- `verbose`:
    defaults to true. If false, all error/info messages will be suppressed.

Examples
--------

```julia
# Read benchmark instance
instance = UnitCommitment.read_benchmark("matpower/case118/2017-02-01")

# Construct model (using state-of-the-art defaults)
model = UnitCommitment.build_model(
    instance = instance,
    optimizer = Cbc.Optimizer,
)

# Get the LMPs before solving the UC model
# Error messages will be displayed and the returned value is false.
# lmp = UnitCommitment.get_lmp(model)

UnitCommitment.optimize!(model)

# Get the LMPs after solving the UC model (the correct way)
# DO NOT use Cbc as the optimizer here. Cbc does not support dual values.
lmp = UnitCommitment.get_lmp(
    model, 
    optimizer=Clp.Optimizer
)

# Accessing the 'lmp' dictionary
# Example: "b1" is the bus name, 1 is the first time slot
@show lmp["b1", 1]

```

"""

function get_lmp(
    model::JuMP.Model; 
    optimizer = nothing,
    verbose::Bool=true
)
    # Validate model, the UC model must be solved beforehand
    if !has_values(model)
        if verbose
            @error "The UC model must be solved before calculating the LMPs."
            @error "The LMPs are NOT calculated."
        end
        return false
    end

    # if optimizer is not specified, use Clp
    if isnothing(optimizer)
        optimizer = Clp.Optimizer
    end

    # Prepare the LMP result dictionary
    lmp = Dict()

    # Calculate LMPs
    # Fix all binary variables to their optimal values and relax integrality
    if verbose
        @info "Calculating LMPs..."
        @info "Fixing all binary variables to their optimal values and relax integrality."
    end
    vals = Dict(v => value(v) for v in all_variables(model))
    for v in all_variables(model)
        if is_binary(v)
            unset_binary(v)
            fix(v, vals[v])
        end
    end
    relax_integrality(model)
    set_optimizer(model, optimizer)

    # Solve the LP
    if verbose
        @info "Solving the LP."
    end
    JuMP.optimize!(model)
    
    # Obtain dual values (LMPs) and store into the LMP dictionary
    if verbose
        @info "Getting dual values (LMPs)."
    end
    for (key, val) in model[:eq_net_injection]
        lmp[key] = dual(val)
    end

    # Return the LMP dictionary
    if verbose
        @info "Calculation completed."
    end
    return lmp
end