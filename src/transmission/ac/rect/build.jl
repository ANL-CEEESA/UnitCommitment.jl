# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using JuMP

function _add_ac_voltage_vars!(
    model::JuMP.Model,
    instance::UnitCommitmentInstance,
    ::ACRectangular,
)::Nothing
    T = instance.time

    vr = _init(model, :vr)
    vi = _init(model, :vi)

    for sc in instance.scenarios, b in sc[:bus], t in 1:T
        vr[sc.name, b.name, t] =
            @variable(model, lower_bound = -b.vmax, upper_bound = b.vmax,)
        vi[sc.name, b.name, t] =
            @variable(model, lower_bound = -b.vmax, upper_bound = b.vmax,)
    end
    return
end

function _add_ac_voltage_constraints!(
    model::JuMP.Model,
    instance::UnitCommitmentInstance,
    ::ACRectangular,
)::Nothing
    T = instance.time

    vr = model[:vr]
    vi = model[:vi]

    eq_voltage_mag_lb = _init(model, :eq_voltage_mag_lb)
    eq_voltage_mag_ub = _init(model, :eq_voltage_mag_ub)
    eq_voltage_ref = _init(model, :eq_voltage_ref)

    for sc in instance.scenarios, b in sc[:bus], t in 1:T
        eq_voltage_mag_lb[sc.name, b.name, t] = @constraint(
            model,
            b.vmin^2 <= vr[sc.name, b.name, t]^2 + vi[sc.name, b.name, t]^2
        )
        eq_voltage_mag_ub[sc.name, b.name, t] = @constraint(
            model,
            vr[sc.name, b.name, t]^2 + vi[sc.name, b.name, t]^2 <= b.vmax^2
        )
        if b.bus_type == "Slack"
            eq_voltage_ref[sc.name, b.name, t] =
                @constraint(model, vi[sc.name, b.name, t] == 0)
        end
    end
    return
end

function _add_ac_ohms!(
    model::JuMP.Model,
    instance::UnitCommitmentInstance,
    ::ACRectangular,
)::Nothing
    T = instance.time

    pf = model[:pf]
    pt = model[:pt]
    qf = model[:qf]
    qt = model[:qt]
    vr = model[:vr]
    vi = model[:vi]

    eq_ac_pf = _init(model, :eq_ac_pf)
    eq_ac_qf = _init(model, :eq_ac_qf)
    eq_ac_pt = _init(model, :eq_ac_pt)
    eq_ac_qt = _init(model, :eq_ac_qt)

    for sc in instance.scenarios
        base_mva = sc[:base_mva]

        for l in sc[:ac_branches], t in 1:T
            p = _ac_branch_params(l)

            vr_fr = vr[sc.name, l.source.name, t]
            vi_fr = vi[sc.name, l.source.name, t]
            vr_to = vr[sc.name, l.target.name, t]
            vi_to = vi[sc.name, l.target.name, t]

            # From-end active power
            eq_ac_pf[sc.name, l.name, t] = @constraint(
                model,
                pf[sc.name, l.name, t] ==
                base_mva * (
                    (p.g + p.g_fr) / p.tm2 * (vr_fr^2 + vi_fr^2) +
                    (-p.g * p.tr + p.b * p.ti) / p.tm2 *
                    (vr_fr * vr_to + vi_fr * vi_to) +
                    (-p.b * p.tr - p.g * p.ti) / p.tm2 *
                    (vi_fr * vr_to - vr_fr * vi_to)
                )
            )

            # From-end reactive power
            eq_ac_qf[sc.name, l.name, t] = @constraint(
                model,
                qf[sc.name, l.name, t] ==
                base_mva * (
                    -(p.b + p.b_fr) / p.tm2 * (vr_fr^2 + vi_fr^2) -
                    (-p.b * p.tr - p.g * p.ti) / p.tm2 *
                    (vr_fr * vr_to + vi_fr * vi_to) +
                    (-p.g * p.tr + p.b * p.ti) / p.tm2 *
                    (vi_fr * vr_to - vr_fr * vi_to)
                )
            )

            # To-end active power
            eq_ac_pt[sc.name, l.name, t] = @constraint(
                model,
                pt[sc.name, l.name, t] ==
                base_mva * (
                    (p.g + p.g_to) * (vr_to^2 + vi_to^2) +
                    (-p.g * p.tr - p.b * p.ti) / p.tm2 *
                    (vr_to * vr_fr + vi_to * vi_fr) +
                    (-p.b * p.tr + p.g * p.ti) / p.tm2 *
                    (vi_to * vr_fr - vr_to * vi_fr)
                )
            )

            # To-end reactive power
            eq_ac_qt[sc.name, l.name, t] = @constraint(
                model,
                qt[sc.name, l.name, t] ==
                base_mva * (
                    -(p.b + p.b_to) * (vr_to^2 + vi_to^2) -
                    (-p.b * p.tr + p.g * p.ti) / p.tm2 *
                    (vr_to * vr_fr + vi_to * vi_fr) +
                    (-p.g * p.tr - p.b * p.ti) / p.tm2 *
                    (vi_to * vr_fr - vr_to * vi_fr)
                )
            )
        end
    end
    return
end

function _add_ac_angle_diff!(
    model::JuMP.Model,
    instance::UnitCommitmentInstance,
    ::ACRectangular,
)::Nothing
    T = instance.time

    vr = model[:vr]
    vi = model[:vi]

    eq_angle_diff_lb = _init(model, :eq_angle_diff_lb)
    eq_angle_diff_ub = _init(model, :eq_angle_diff_ub)

    for sc in instance.scenarios, l in sc[:ac_branches], t in 1:T
        vr_fr = vr[sc.name, l.source.name, t]
        vi_fr = vi[sc.name, l.source.name, t]
        vr_to = vr[sc.name, l.target.name, t]
        vi_to = vi[sc.name, l.target.name, t]

        if isfinite(l.angle_diff_min)
            eq_angle_diff_lb[sc.name, l.name, t] = @constraint(
                model,
                tan(l.angle_diff_min) * (vr_fr * vr_to + vi_fr * vi_to) <=
                vi_fr * vr_to - vr_fr * vi_to
            )
        end

        if isfinite(l.angle_diff_max)
            eq_angle_diff_ub[sc.name, l.name, t] = @constraint(
                model,
                vi_fr * vr_to - vr_fr * vi_to <=
                tan(l.angle_diff_max) * (vr_fr * vr_to + vi_fr * vi_to)
            )
        end
    end
    return
end

function _add_ac_nodal_balance!(
    model::JuMP.Model,
    instance::UnitCommitmentInstance,
    ::ACRectangular,
)::Nothing
    T = instance.time

    pf = model[:pf]
    pt = model[:pt]
    qf = model[:qf]
    qt = model[:qt]
    vr = model[:vr]
    vi = model[:vi]

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

        # Add shunt contributions (quadratic in voltage).
        # Use auxiliary variables to keep net_injection as AffExpr.
        for sh in sc[:shunts], t in 1:T
            b = sh.bus
            if sh.status[t]
                vm2 = vr[sc.name, b.name, t]^2 + vi[sc.name, b.name, t]^2

                # Shunt active power consumed: gs * |V|^2 * base_mva
                p_shunt = @variable(model)
                @constraint(model, p_shunt == base_mva * sh.conductance * vm2,)
                add_to_expression!(
                    net_injection[sc.name, b.name, t],
                    p_shunt,
                    -1.0,
                )

                # Shunt reactive power injected: bs * |V|^2 * base_mva
                q_shunt = @variable(model)
                @constraint(model, q_shunt == base_mva * sh.susceptance * vm2,)
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
