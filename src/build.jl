# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using JuMP, MathOptInterface, DataStructures
import JuMP: value, fix, set_name

function build_model(;
    instance::UnitCommitmentInstance,
    optimizer = nothing,
    variable_names::Bool = false,
)::JuMP.Model
    model = Model()
    model.ext[:ucjl] = Dict()

    model[:obj] = AffExpr()
    model[:net_injection] = OrderedDict(
        (sc.name, b.name, t) => AffExpr(-b.load[t]) for
        sc in instance.scenarios for b in sc[:bus] for
        t in 1:instance.time
    )

    model[:instance] = instance

    for ext in instance.extensions
        build_model(model, instance, ext)
    end

    _add_buses!(model, instance)

    @objective(model, Min, model[:obj])

    if variable_names
        _set_names!(model)
    end

    if optimizer !== nothing
        set_optimizer(model, optimizer)
    end

    return model
end
