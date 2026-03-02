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
        vr[sc.name, b.name, t] = @variable(
            model,
            lower_bound = -b.vmax,
            upper_bound = b.vmax,
            start = 1.0,
        )
        vi[sc.name, b.name, t] = @variable(
            model,
            lower_bound = -b.vmax,
            upper_bound = b.vmax,
            start = 0.0,
        )
    end
    return
end

function _add_ac_constr_voltage!(
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

function _add_ac_constr_angle_diff!(
    model::JuMP.Model,
    instance::UnitCommitmentInstance,
    ::ACRectangular,
)::Nothing
    T = instance.time

    vr = model[:vr]
    vi = model[:vi]

    eq_angle_diff_lb = _init(model, :eq_angle_diff_lb)
    eq_angle_diff_ub = _init(model, :eq_angle_diff_ub)

    for sc in instance.scenarios, l in sc[:branches], t in 1:T
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

function _ac_voltage_products(model::JuMP.Model, sc, l, t, ::ACRectangular)
    vr = model[:vr]
    vi = model[:vi]
    vr_fr = vr[sc.name, l.source.name, t]
    vi_fr = vi[sc.name, l.source.name, t]
    vr_to = vr[sc.name, l.target.name, t]
    vi_to = vi[sc.name, l.target.name, t]
    return (
        v_sq_fr = vr_fr^2 + vi_fr^2,
        v_sq_to = vr_to^2 + vi_to^2,
        v_cos = vr_fr * vr_to + vi_fr * vi_to,
        v_sin = vi_fr * vr_to - vr_fr * vi_to,
    )
end

function _ac_voltage_sq(
    model::JuMP.Model,
    sc_name,
    bus_name,
    t,
    ::ACRectangular,
)
    vr = model[:vr]
    vi = model[:vi]
    return vr[sc_name, bus_name, t]^2 + vi[sc_name, bus_name, t]^2
end
