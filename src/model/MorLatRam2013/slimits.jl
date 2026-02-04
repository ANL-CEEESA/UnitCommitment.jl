# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

function _add_thermal_constr_slimits!(
    model::JuMP.Model,
    instance::UnitCommitmentInstance,
    ::MorLatRam2013.StartupShutdownLimits,
)::Nothing
    eq_slimit_a = _init(model, :eq_slimit_a)
    eq_slimit_b = _init(model, :eq_slimit_b)
    eq_slimit_c = _init(model, :eq_slimit_c)
    eq_slimit_init = _init(model, :eq_slimit_init)

    is_on = model[:is_on]
    prod_above = model[:prod_above]
    switch_off = model[:switch_off]
    switch_on = model[:switch_on]
    T = instance.time

    for sc in instance.scenarios, g in sc.thermal_units
        reserve = _total_reserves(model, instance, g, sc)
        if g.min_uptime > 1
            # Equation (20) in Kneuven et al. (2020)
            for t in 1:T
                eq_slimit_a[sc.name, g.name, t] = @constraint(
                    model,
                    prod_above[sc.name, g.name, t] + reserve[t] <=
                    (g.max_power[t] - g.min_power[t]) * is_on[g.name, t] -
                    (g.max_power[t] - g.startup_limit) * switch_on[g.name, t] -
                    (g.max_power[t] - g.shutdown_limit) *
                    switch_off[g.name, t+1]
                )
            end
        else
            # Equation (21a) in Kneuven et al. (2020)
            for t in 1:T
                eq_slimit_b[sc.name, g.name, t] = @constraint(
                    model,
                    prod_above[sc.name, g.name, t] + reserve[t] <=
                    (g.max_power[t] - g.min_power[t]) * is_on[g.name, t] -
                    (g.max_power[t] - g.startup_limit) * switch_on[g.name, t]
                )
            end

            # Equation (21b) in Kneuven et al. (2020)
            for t in 1:T
                eq_slimit_c[sc.name, g.name, t] = @constraint(
                    model,
                    prod_above[sc.name, g.name, t] + reserve[t] <=
                    (g.max_power[t] - g.min_power[t]) * is_on[g.name, t] -
                    (g.max_power[t] - g.shutdown_limit) *
                    switch_off[g.name, t+1]
                )
            end
        end

        # Initial time step
        if g.initial_power > g.shutdown_limit
            eq_slimit_init[sc.name, g.name] =
                @constraint(model, switch_off[g.name, 1] <= 0)
        end
    end
    return
end
