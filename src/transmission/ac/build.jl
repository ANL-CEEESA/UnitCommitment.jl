# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using JuMP

function build_model(
    model::JuMP.Model,
    instance::UnitCommitmentInstance,
    ext::ACTransmissionExt,
)::Nothing
    build_model(model, instance, CopperPlateTransmissionExt())
    _add_ac_voltage_vars!(model, instance, ext.formulation)
    _add_ac_flow_vars!(model, instance)
    _add_ac_voltage_constraints!(model, instance, ext.formulation)
    _add_ac_ohms!(model, instance, ext.formulation)
    _add_ac_flow_limits!(model, instance)
    _add_ac_angle_diff!(model, instance, ext.formulation)
    _add_ac_nodal_balance!(model, instance, ext.formulation)
    _add_ac_obj!(model, instance)
    return
end

"""
    _ac_branch_params(branch)

Compute derived parameters for an AC branch, used by Ohm's law constraints.
Returns a named tuple with fields: g, b, g_fr, b_fr, g_to, b_to, tr, ti, tm2.
"""
function _ac_branch_params(branch::ACBranch)
    r = branch.resistance
    x = branch.reactance
    z2 = r^2 + x^2
    g = r / z2
    b = -x / z2
    g_fr = branch.shunt_conductance / 2
    b_fr = branch.shunt_susceptance / 2
    g_to = branch.shunt_conductance / 2
    b_to = branch.shunt_susceptance / 2
    tr = branch.tap_ratio * cos(branch.phase_shift)
    ti = branch.tap_ratio * sin(branch.phase_shift)
    tm2 = tr^2 + ti^2
    return (; g, b, g_fr, b_fr, g_to, b_to, tr, ti, tm2)
end

function _add_ac_flow_vars!(
    model::JuMP.Model,
    instance::UnitCommitmentInstance,
)::Nothing
    T = instance.time

    pf = _init(model, :pf)
    pt = _init(model, :pt)
    qf = _init(model, :qf)
    qt = _init(model, :qt)
    overflow = _init(model, :overflow)

    for sc in instance.scenarios, l in sc[:ac_branches], t in 1:T
        pf[sc.name, l.name, t] = @variable(model)
        pt[sc.name, l.name, t] = @variable(model)
        qf[sc.name, l.name, t] = @variable(model)
        qt[sc.name, l.name, t] = @variable(model)
        overflow[sc.name, l.name, t] = @variable(model, lower_bound = 0)
    end
    return
end

function _add_ac_flow_limits!(
    model::JuMP.Model,
    instance::UnitCommitmentInstance,
)::Nothing
    T = instance.time

    pf = model[:pf]
    pt = model[:pt]
    qf = model[:qf]
    qt = model[:qt]
    overflow = model[:overflow]

    eq_flow_limit_fr_ub = _init(model, :eq_flow_limit_fr_ub)
    eq_flow_limit_to_ub = _init(model, :eq_flow_limit_to_ub)

    for sc in instance.scenarios, l in sc[:ac_branches], t in 1:T
        limit = l.normal_flow_limit[t]
        eq_flow_limit_fr_ub[sc.name, l.name, t] = @constraint(
            model,
            pf[sc.name, l.name, t]^2 + qf[sc.name, l.name, t]^2 <=
            (limit + overflow[sc.name, l.name, t])^2
        )
        eq_flow_limit_to_ub[sc.name, l.name, t] = @constraint(
            model,
            pt[sc.name, l.name, t]^2 + qt[sc.name, l.name, t]^2 <=
            (limit + overflow[sc.name, l.name, t])^2
        )
    end
    return
end

function _add_ac_obj!(
    model::JuMP.Model,
    instance::UnitCommitmentInstance,
)::Nothing
    T = instance.time
    overflow = model[:overflow]

    for sc in instance.scenarios, l in sc[:ac_branches], t in 1:T
        add_to_expression!(
            model[:obj],
            overflow[sc.name, l.name, t],
            l.flow_limit_penalty[t] * sc[:probability],
        )
    end
    return
end
