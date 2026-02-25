# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using JuMP

function _add_ac_voltage_vars!(
    model::JuMP.Model,
    instance::UnitCommitmentInstance,
    ::ACPolar,
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

function _add_ac_constr_voltage!(
    model::JuMP.Model,
    instance::UnitCommitmentInstance,
    ::ACPolar,
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

function _add_ac_constr_angle_diff!(
    model::JuMP.Model,
    instance::UnitCommitmentInstance,
    ::ACPolar,
)::Nothing
    T = instance.time

    va = model[:va]

    eq_angle_diff_lb = _init(model, :eq_angle_diff_lb)
    eq_angle_diff_ub = _init(model, :eq_angle_diff_ub)

    for sc in instance.scenarios, l in sc[:branches], t in 1:T
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

function _ac_voltage_products(model::JuMP.Model, sc, l, t, ::ACPolar)
    vm = model[:vm]
    va = model[:va]
    vm_fr = vm[sc.name, l.source.name, t]
    va_fr = va[sc.name, l.source.name, t]
    vm_to = vm[sc.name, l.target.name, t]
    va_to = va[sc.name, l.target.name, t]
    return (
        v_sq_fr = vm_fr^2,
        v_sq_to = vm_to^2,
        v_cos = vm_fr * vm_to * cos(va_fr - va_to),
        v_sin = vm_fr * vm_to * sin(va_fr - va_to),
    )
end

function _ac_voltage_sq(model::JuMP.Model, sc_name, bus_name, t, ::ACPolar)
    return model[:vm][sc_name, bus_name, t]^2
end
