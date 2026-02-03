# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

function _add_thermal_constr_pwl_costs!(
    model::JuMP.Model,
    instance::UnitCommitmentInstance,
    ::KnuOstWat2018.PwlCosts,
)::Nothing
    T = instance.time
    is_on = model[:is_on]
    switch_off = model[:switch_off]
    switch_on = model[:switch_on]
    segprod = model[:segprod]

    eq_segprod_limit_a = _init(model, :eq_segprod_limit_a)
    eq_segprod_limit_b = _init(model, :eq_segprod_limit_b)
    eq_segprod_limit_c = _init(model, :eq_segprod_limit_c)

    # Add base PWL cost constraints
    _add_thermal_constr_pwl_costs!(model, instance, BasePwlCosts())

    # Tighten bounds on segprod based on startup/shutdown limits
    for sc in instance.scenarios, g in sc.thermal_units
        gn = g.name
        K = length(g.cost_segments)
        for t in 1:T, k in 1:K
            # Pbar^{k-1)
            Pbar0 =
                g.min_power[t] +
                (k > 1 ? sum(g.cost_segments[ell].mw[t] for ell in 1:k-1) : 0.0)
            # Pbar^k
            Pbar1 = g.cost_segments[k].mw[t] + Pbar0

            Cv = 0.0
            SU = g.startup_limit   # startup rate
            if Pbar1 <= SU
                Cv = 0.0
            elseif Pbar0 < SU # && Pbar1 > SU
                Cv = Pbar1 - SU
            else # Pbar0 >= SU
                # this will imply that we cannot produce along this segment if
                # switch_on = 1
                Cv = g.cost_segments[k].mw[t]
            end
            Cw = 0.0
            SD = g.shutdown_limit  # shutdown rate
            if Pbar1 <= SD
                Cw = 0.0
            elseif Pbar0 < SD # && Pbar1 > SD
                Cw = Pbar1 - SD
            else # Pbar0 >= SD
                Cw = g.cost_segments[k].mw[t]
            end

            if g.min_uptime > 1
                # Equation (46) in Kneuven et al. (2020)
                eq_segprod_limit_a[sc.name, gn, t, k] = @constraint(
                    model,
                    segprod[sc.name, gn, t, k] <=
                    g.cost_segments[k].mw[t] * is_on[gn, t] -
                    Cv * switch_on[gn, t] -
                    (t < T ? Cw * switch_off[gn, t+1] : 0.0)
                )
            else
                # Equation (47a) in Kneuven et al. (2020)
                eq_segprod_limit_b[sc.name, gn, t, k] = @constraint(
                    model,
                    segprod[sc.name, gn, t, k] <=
                    g.cost_segments[k].mw[t] * is_on[gn, t] -
                    Cv * switch_on[gn, t]
                )

                if t < T
                    # Equation (47b) in Kneuven et al. (2020)
                    eq_segprod_limit_c[sc.name, gn, t, k] = @constraint(
                        model,
                        segprod[sc.name, gn, t, k] <=
                        g.cost_segments[k].mw[t] * is_on[gn, t] -
                        Cw * switch_off[gn, t+1]
                    )
                end
            end
        end
    end
end
