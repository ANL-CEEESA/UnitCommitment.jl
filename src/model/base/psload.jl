# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

function _add_ps_loads!(
    model::JuMP.Model,
    instance::UnitCommitmentInstance,
)::Nothing
    _add_ps_load_vars!(model, instance)
    _add_ps_load_obj!(model, instance)
    return
end

function _add_ps_load_vars!(
    model::JuMP.Model,
    instance::UnitCommitmentInstance,
)::Nothing
    T = instance.time
    loads = _init(model, :loads)

    for sc in instance.scenarios, ps in sc.price_sensitive_loads
        for t in 1:T
            loads[sc.name, ps.name, t] = @variable(
                model,
                lower_bound = 0,
                upper_bound = ps.demand[t],
            )
            add_to_expression!(
                model[:net_injection][sc.name, ps.bus.name, t],
                loads[sc.name, ps.name, t],
                -1.0,
            )
        end
    end
    return
end

function _add_ps_load_obj!(
    model::JuMP.Model,
    instance::UnitCommitmentInstance,
)::Nothing
    T = instance.time
    loads = model[:loads]

    for t in 1:T, sc in instance.scenarios, ps in sc.price_sensitive_loads
        add_to_expression!(
            model[:obj],
            loads[sc.name, ps.name, t],
            -ps.revenue[t] * sc.probability,
        )
    end
    return
end
