# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using JuMP, MathOptInterface, DataStructures
import JuMP: value, fix, set_name

const BaseFormulation =
    Formulation(pwl_costs = BasePwlCosts(), ramping = MorLatRam2013.Ramping())

function build_model(;
    instance::UnitCommitmentInstance,
    optimizer = nothing,
    formulation = Formulation(),
    variable_names::Bool = false,
)::JuMP.Model
    model = Model()
    model[:obj] = AffExpr()

    _add_thermal_units!(model, instance, formulation)

    @objective(model, Min, model[:obj])

    if variable_names
        _set_names!(model)
    end

    if optimizer !== nothing
        set_optimizer(model, optimizer)
    end

    return model
end
