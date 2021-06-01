# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

function _add_production_piecewise_linear_eqs!(
    model::JuMP.Model,
    g::Unit,
    formulation::KnuOstWat2018.PwlCosts,
)::Nothing
    eq_prod_above_def = _init(model, :eq_prod_above_def)
    eq_segprod_limit_a = _init(model, :eq_segprod_limit_a)
    eq_segprod_limit_b = _init(model, :eq_segprod_limit_b)
    eq_segprod_limit_c = _init(model, :eq_segprod_limit_c)
    prod_above = model[:prod_above]
    segprod = model[:segprod]
    is_on = model[:is_on]
    switch_on = model[:switch_on]
    switch_off = model[:switch_off]
    gn = g.name
    K = length(g.cost_segments)
    T = model[:instance].time

    for t in 1:T
        for k in 1:K
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
                eq_segprod_limit_a[gn, t, k] = @constraint(
                    model,
                    segprod[gn, t, k] <=
                    g.cost_segments[k].mw[t] * is_on[gn, t] -
                    Cv * switch_on[gn, t] -
                    (t < T ? Cw * switch_off[gn, t+1] : 0.0)
                )
            else
                # Equation (47a)/(48a) in Kneuven et al. (2020)
                eq_segprod_limit_b[gn, t, k] = @constraint(
                    model,
                    segprod[gn, t, k] <=
                    g.cost_segments[k].mw[t] * is_on[gn, t] -
                    Cv * switch_on[gn, t] -
                    (t < T ? max(0, Cv - Cw) * switch_off[gn, t+1] : 0.0)
                )

                # Equation (47b)/(48b) in Kneuven et al. (2020)
                eq_segprod_limit_c[gn, t, k] = @constraint(
                    model,
                    segprod[gn, t, k] <=
                    g.cost_segments[k].mw[t] * is_on[gn, t] -
                    max(0, Cw - Cv) * switch_on[gn, t] -
                    (t < T ? Cw * switch_off[gn, t+1] : 0.0)
                )
            end

            # Definition of production
            # Equation (43) in Kneuven et al. (2020)
            eq_prod_above_def[gn, t] = @constraint(
                model,
                prod_above[gn, t] == sum(segprod[gn, t, k] for k in 1:K)
            )

            # Objective function
            # Equation (44) in Kneuven et al. (2020)
            add_to_expression!(
                model[:obj],
                segprod[gn, t, k],
                g.cost_segments[k].cost[t],
            )

            # Also add an explicit upper bound on segprod to make the solver's
            # work a bit easier
            set_upper_bound(segprod[gn, t, k], g.cost_segments[k].mw[t])
        end
    end
end
