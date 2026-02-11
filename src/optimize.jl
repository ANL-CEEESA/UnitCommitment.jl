# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

"""
    JuMP.optimize!(model::UnitCommitmentModel)

Solve the unit commitment model. Automatically selects the appropriate solution
method based on the model configuration.

# Example
```julia
model = UnitCommitment.build_model(instance, optimizer=HiGHS.Optimizer)
JuMP.optimize!(model)
```
"""
function JuMP.optimize!(model::UnitCommitmentModel)::Nothing
    instance = model.inner[:instance]
    transmission_ext = get(instance.extension_by_slot, :transmission, nothing)
    if transmission_ext isa ShiftFactorsTransmissionExt && transmission_ext.lazy
        optimize!(model, XavQiuWanThi2019.Method())
    else
        optimize!(model, DirectMethod())
    end
end

"""
    optimize!(model::UnitCommitmentModel, ::DirectMethod)

Solve the unit commitment model using the direct method, which solves the
complete problem as a single MILP.
"""
function optimize!(model::UnitCommitmentModel, ::DirectMethod)::Nothing
    optimize!(model.inner)
    _store_solution!(model)
    for ext in model.inner[:instance].extensions
        _after_optimize!(model.inner, ext)
    end
    validate(model.inner[:instance], model.data[:solution]) ||
        error("Invalid solution found.")
    return
end
