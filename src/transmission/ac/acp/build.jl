# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using JuMP

function _add_ac_voltage_vars!(
    model::JuMP.Model,
    instance::UnitCommitmentInstance,
    ::ACP.Formulation,
)::Nothing
    T = instance.time

    vm = _init(model, :vm)
    va = _init(model, :va)

    for sc in instance.scenarios, b in sc[:bus], t in 1:T
        vm[sc.name, b.name, t] =
            @variable(model, lower_bound = b.vmin, upper_bound = b.vmax,)
        va[sc.name, b.name, t] = @variable(model)
    end
    return
end

function _add_ac_voltage_constraints!(
    model::JuMP.Model,
    instance::UnitCommitmentInstance,
    ::ACP.Formulation,
)::Nothing
    T = instance.time

    va = model[:va]

    eq_voltage_ref = _init(model, :eq_voltage_ref)

    for sc in instance.scenarios, b in sc[:bus], t in 1:T
        if b.bus_type == "Slack"
            eq_voltage_ref[sc.name, b.name, t] =
                @constraint(model, va[sc.name, b.name, t] == 0)
        end
    end
    return
end

function _add_ac_ohms!(
    model::JuMP.Model,
    instance::UnitCommitmentInstance,
    ::ACP.Formulation,
)::Nothing
    T = instance.time

    pf = model[:pf]
    pt = model[:pt]
    qf = model[:qf]
    qt = model[:qt]
    vm = model[:vm]
    va = model[:va]

    eq_ac_pf = _init(model, :eq_ac_pf)
    eq_ac_qf = _init(model, :eq_ac_qf)
    eq_ac_pt = _init(model, :eq_ac_pt)
    eq_ac_qt = _init(model, :eq_ac_qt)

    for sc in instance.scenarios
        base_mva = sc[:base_mva]

        for l in sc[:ac_branches], t in 1:T
            p = _ac_branch_params(l)

            vm_fr = vm[sc.name, l.source.name, t]
            va_fr = va[sc.name, l.source.name, t]
            vm_to = vm[sc.name, l.target.name, t]
            va_to = va[sc.name, l.target.name, t]

            # From-end active power
            eq_ac_pf[sc.name, l.name, t] = @constraint(
                model,
                pf[sc.name, l.name, t] ==
                base_mva * (
                    (p.g + p.g_fr) / p.tm2 * vm_fr^2 +
                    (-p.g * p.tr + p.b * p.ti) / p.tm2 *
                    (vm_fr * vm_to * cos(va_fr - va_to)) +
                    (-p.b * p.tr - p.g * p.ti) / p.tm2 *
                    (vm_fr * vm_to * sin(va_fr - va_to))
                )
            )

            # From-end reactive power
            eq_ac_qf[sc.name, l.name, t] = @constraint(
                model,
                qf[sc.name, l.name, t] ==
                base_mva * (
                    -(p.b + p.b_fr) / p.tm2 * vm_fr^2 -
                    (-p.b * p.tr - p.g * p.ti) / p.tm2 *
                    (vm_fr * vm_to * cos(va_fr - va_to)) +
                    (-p.g * p.tr + p.b * p.ti) / p.tm2 *
                    (vm_fr * vm_to * sin(va_fr - va_to))
                )
            )

            # To-end active power
            eq_ac_pt[sc.name, l.name, t] = @constraint(
                model,
                pt[sc.name, l.name, t] ==
                base_mva * (
                    (p.g + p.g_to) * vm_to^2 +
                    (-p.g * p.tr - p.b * p.ti) / p.tm2 *
                    (vm_to * vm_fr * cos(va_to - va_fr)) +
                    (-p.b * p.tr + p.g * p.ti) / p.tm2 *
                    (vm_to * vm_fr * sin(va_to - va_fr))
                )
            )

            # To-end reactive power
            eq_ac_qt[sc.name, l.name, t] = @constraint(
                model,
                qt[sc.name, l.name, t] ==
                base_mva * (
                    -(p.b + p.b_to) * vm_to^2 -
                    (-p.b * p.tr + p.g * p.ti) / p.tm2 *
                    (vm_to * vm_fr * cos(va_to - va_fr)) +
                    (-p.g * p.tr - p.b * p.ti) / p.tm2 *
                    (vm_to * vm_fr * sin(va_to - va_fr))
                )
            )
        end
    end
    return
end

function _add_ac_angle_diff!(
    model::JuMP.Model,
    instance::UnitCommitmentInstance,
    ::ACP.Formulation,
)::Nothing
    T = instance.time

    va = model[:va]

    eq_angle_diff_lb = _init(model, :eq_angle_diff_lb)
    eq_angle_diff_ub = _init(model, :eq_angle_diff_ub)

    for sc in instance.scenarios, l in sc[:ac_branches], t in 1:T
        va_fr = va[sc.name, l.source.name, t]
        va_to = va[sc.name, l.target.name, t]

        if isfinite(l.angle_diff_min)
            eq_angle_diff_lb[sc.name, l.name, t] =
                @constraint(model, l.angle_diff_min <= va_fr - va_to)
        end

        if isfinite(l.angle_diff_max)
            eq_angle_diff_ub[sc.name, l.name, t] =
                @constraint(model, va_fr - va_to <= l.angle_diff_max)
        end
    end
    return
end

function _add_ac_nodal_balance!(
    model::JuMP.Model,
    instance::UnitCommitmentInstance,
    ::ACP.Formulation,
)::Nothing
    T = instance.time

    pf = model[:pf]
    pt = model[:pt]
    qf = model[:qf]
    qt = model[:qt]
    vm = model[:vm]

    net_injection = model[:net_injection]
    net_reactive_injection = model[:net_reactive_injection]

    for sc in instance.scenarios
        base_mva = sc[:base_mva]

        # Add line flow contributions to net injection expressions
        for l in sc[:ac_branches], t in 1:T
            # Active power: subtract flows leaving the bus
            add_to_expression!(
                net_injection[sc.name, l.source.name, t],
                pf[sc.name, l.name, t],
                -1.0,
            )
            add_to_expression!(
                net_injection[sc.name, l.target.name, t],
                pt[sc.name, l.name, t],
                -1.0,
            )

            # Reactive power: subtract flows leaving the bus
            add_to_expression!(
                net_reactive_injection[sc.name, l.source.name, t],
                qf[sc.name, l.name, t],
                -1.0,
            )
            add_to_expression!(
                net_reactive_injection[sc.name, l.target.name, t],
                qt[sc.name, l.name, t],
                -1.0,
            )
        end

        # Add shunt contributions (quadratic in voltage magnitude).
        # Use auxiliary variables to keep net_injection as AffExpr.
        for sh in sc[:shunts], t in 1:T
            b = sh.bus
            if sh.status[t]
                vm_b = vm[sc.name, b.name, t]

                # Shunt active power consumed: gs * |V|^2 * base_mva
                p_shunt = @variable(model)
                @constraint(
                    model,
                    p_shunt == base_mva * sh.conductance * vm_b^2,
                )
                add_to_expression!(
                    net_injection[sc.name, b.name, t],
                    p_shunt,
                    -1.0,
                )

                # Shunt reactive power injected: bs * |V|^2 * base_mva
                q_shunt = @variable(model)
                @constraint(
                    model,
                    q_shunt == base_mva * sh.susceptance * vm_b^2,
                )
                add_to_expression!(
                    net_reactive_injection[sc.name, b.name, t],
                    q_shunt,
                    1.0,
                )
            end
        end
    end
    return
end
