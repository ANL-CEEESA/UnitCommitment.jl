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
    _add_ac_shunt_vars!(model, instance, ext.formulation)
    _add_ac_constr_voltage!(model, instance, ext.formulation)
    _add_ac_constr_ohms!(model, instance, ext.formulation)
    _add_ac_constr_flow_limits!(model, instance)
    _add_ac_constr_angle_diff!(model, instance, ext.formulation)
    _add_ac_constr_nodal_balance!(model, instance, ext.formulation)
    _add_ac_obj!(model, instance)
    return
end

"""
    _ac_branch_params(branch)

Compute derived parameters for an AC branch, used by Ohm's law constraints.
Returns a named tuple with fields: g, b, g_fr, b_fr, g_to, b_to, tr, ti, tm2.
"""
function _ac_branch_params(branch::Branch)
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

    for sc in instance.scenarios, l in sc[:branches], t in 1:T
        pf[sc.name, l.name, t] = @variable(model)
        pt[sc.name, l.name, t] = @variable(model)
        qf[sc.name, l.name, t] = @variable(model)
        qt[sc.name, l.name, t] = @variable(model)
        overflow[sc.name, l.name, t] = @variable(model, lower_bound = 0)
    end
    return
end

function _add_ac_shunt_vars!(
    model::JuMP.Model,
    instance::UnitCommitmentInstance,
    formulation::ACFormulation,
)::Nothing
    T = instance.time

    p_shunt = _init(model, :p_shunt)
    q_shunt = _init(model, :q_shunt)

    for sc in instance.scenarios
        for sh in sc[:shunts], t in 1:T
            sh.status[t] || continue
            p_shunt[sc.name, sh.name, t] = @variable(model)
            q_shunt[sc.name, sh.name, t] = @variable(model)
        end
    end
    return
end

function _add_ac_constr_flow_limits!(
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

    for sc in instance.scenarios, l in sc[:branches], t in 1:T
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

    for sc in instance.scenarios, l in sc[:branches], t in 1:T
        add_to_expression!(
            model[:obj],
            overflow[sc.name, l.name, t],
            l.flow_limit_penalty[t] * sc[:probability],
        )
    end
    return
end

function _add_ac_constr_ohms!(
    model::JuMP.Model,
    instance::UnitCommitmentInstance,
    formulation::ACFormulation,
)::Nothing
    T = instance.time

    pf = model[:pf]
    pt = model[:pt]
    qf = model[:qf]
    qt = model[:qt]

    eq_ac_pf = _init(model, :eq_ac_pf)
    eq_ac_qf = _init(model, :eq_ac_qf)
    eq_ac_pt = _init(model, :eq_ac_pt)
    eq_ac_qt = _init(model, :eq_ac_qt)

    for sc in instance.scenarios
        base_mva = sc[:base_mva]

        for l in sc[:branches], t in 1:T
            p = _ac_branch_params(l)
            v = _ac_voltage_products(model, sc, l, t, formulation)

            # From-end active power
            eq_ac_pf[sc.name, l.name, t] = @constraint(
                model,
                pf[sc.name, l.name, t] ==
                base_mva * (
                    (p.g + p.g_fr) / p.tm2 * v.v_sq_fr +
                    (-p.g * p.tr + p.b * p.ti) / p.tm2 * v.v_cos +
                    (-p.b * p.tr - p.g * p.ti) / p.tm2 * v.v_sin
                )
            )

            # From-end reactive power
            eq_ac_qf[sc.name, l.name, t] = @constraint(
                model,
                qf[sc.name, l.name, t] ==
                base_mva * (
                    -(p.b + p.b_fr) / p.tm2 * v.v_sq_fr -
                    (-p.b * p.tr - p.g * p.ti) / p.tm2 * v.v_cos +
                    (-p.g * p.tr + p.b * p.ti) / p.tm2 * v.v_sin
                )
            )

            # To-end active power
            #   cos(va_to - va_fr) = cos(va_fr - va_to) = v.v_cos
            #   sin(va_to - va_fr) = -sin(va_fr - va_to) = -v.v_sin
            eq_ac_pt[sc.name, l.name, t] = @constraint(
                model,
                pt[sc.name, l.name, t] ==
                base_mva * (
                    (p.g + p.g_to) * v.v_sq_to +
                    (-p.g * p.tr - p.b * p.ti) / p.tm2 * v.v_cos +
                    -(-p.b * p.tr + p.g * p.ti) / p.tm2 * v.v_sin
                )
            )

            # To-end reactive power
            eq_ac_qt[sc.name, l.name, t] = @constraint(
                model,
                qt[sc.name, l.name, t] ==
                base_mva * (
                    -(p.b + p.b_to) * v.v_sq_to -
                    (-p.b * p.tr + p.g * p.ti) / p.tm2 * v.v_cos +
                    -(-p.g * p.tr - p.b * p.ti) / p.tm2 * v.v_sin
                )
            )
        end
    end
    return
end

function _add_ac_constr_nodal_balance!(
    model::JuMP.Model,
    instance::UnitCommitmentInstance,
    formulation::ACFormulation,
)::Nothing
    T = instance.time

    ni = model[:ni]
    qi = model[:qi]
    pf = model[:pf]
    pt = model[:pt]
    qf = model[:qf]
    qt = model[:qt]

    eq_nodal_balance = _init(model, :eq_nodal_balance)
    eq_reactive_nodal_balance = _init(model, :eq_reactive_nodal_balance)
    eq_p_shunt = _init(model, :eq_p_shunt)
    eq_q_shunt = _init(model, :eq_q_shunt)

    for sc in instance.scenarios
        base_mva = sc[:base_mva]
        shunts_by_bus = sc[:shunts_by_bus]
        branches_by_source = sc[:branches_by_source_bus]
        branches_by_target = sc[:branches_by_target_bus]

        for t in 1:T, b in sc[:bus]
            # Active power nodal balance:
            #   ni == sum(pf for source lines) + sum(pt for target lines) + sum(p_shunt)
            outflow = AffExpr()
            for l in branches_by_source[b]
                add_to_expression!(outflow, pf[sc.name, l.name, t])
            end
            for l in branches_by_target[b]
                add_to_expression!(outflow, pt[sc.name, l.name, t])
            end

            # Reactive power nodal balance:
            #   qi == sum(qf for source lines) + sum(qt for target lines) - sum(q_shunt)
            reactive_outflow = AffExpr()
            for l in branches_by_source[b]
                add_to_expression!(reactive_outflow, qf[sc.name, l.name, t])
            end
            for l in branches_by_target[b]
                add_to_expression!(reactive_outflow, qt[sc.name, l.name, t])
            end

            # Shunt contributions (quadratic in voltage magnitude).
            # Use auxiliary variables to keep the balance constraints linear.
            for sh in shunts_by_bus[b]
                sh.status[t] || continue
                vm2 = _ac_voltage_sq(model, sc.name, b.name, t, formulation)

                ps = model[:p_shunt][sc.name, sh.name, t]
                eq_p_shunt[sc.name, sh.name, t] =
                    @constraint(model, ps == base_mva * sh.conductance * vm2)
                add_to_expression!(outflow, ps)

                qs = model[:q_shunt][sc.name, sh.name, t]
                eq_q_shunt[sc.name, sh.name, t] =
                    @constraint(model, qs == base_mva * sh.susceptance * vm2)
                add_to_expression!(reactive_outflow, qs, -1.0)
            end

            eq_nodal_balance[sc.name, b.name, t] =
                @constraint(model, ni[sc.name, b.name, t] == outflow)
            eq_reactive_nodal_balance[sc.name, b.name, t] =
                @constraint(model, qi[sc.name, b.name, t] == reactive_outflow)
        end
    end
    return
end
