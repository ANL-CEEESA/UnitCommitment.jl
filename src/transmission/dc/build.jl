# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

function _check(::UnitCommitmentInstance, ::DCTransmissionExt)::Nothing
    return
end

function build_model(
    model::JuMP.Model,
    instance::UnitCommitmentInstance,
    ext::DCTransmissionExt,
)::Nothing
    build_model(model, instance, CopperPlateTransmissionExt())
    _check(instance, ext)
    _add_dc_vars!(model, instance, ext)
    _add_dc_obj!(model, instance, ext)
    _add_dc_constr_flow!(model, instance, ext)
    return
end

function _add_dc_obj!(
    model::JuMP.Model,
    instance::UnitCommitmentInstance,
    ::DCTransmissionExt,
)::Nothing
    T = instance.time
    overflow = model[:overflow]

    # Overflow penalty
    for sc in instance.scenarios, branch in sc[:branches], t in 1:T
        branch.flow_limit_penalty[t] < 0 && continue
        add_to_expression!(
            model[:obj],
            overflow[sc.name, branch.name, t],
            branch.flow_limit_penalty[t] * sc[:probability],
        )
    end

    # Investment cost
    for branch in instance.scenarios[1][:branches]
        branch.invest > 0.0 || continue
        add_to_expression!(
            model[:obj],
            model[:invest][branch.name],
            branch.invest * instance.scenarios[1][:investment_cost_weight],
        )
    end
    return
end
