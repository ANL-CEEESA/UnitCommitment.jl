# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

function _add_production_piecewise_linear_eqs!(
    model::JuMP.Model,
    g::Unit,
    formulation_prod_vars::Gar1962.ProdVars,
    formulation_pwl_costs::KnuOstWat2018.PwlCosts,
    formulation_status_vars::Gar1962.StatusVars,
    sc::UnitCommitmentScenario,
)::Nothing
    eq_prod_above_def = _init(model, :eq_prod_above_def)
    eq_segprod_limit_a = _init(model, :eq_segprod_limit_a)
    eq_segprod_limit_b = _init(model, :eq_segprod_limit_b)
    eq_segprod_limit_c = _init(model, :eq_segprod_limit_c)
    segprod = model[:segprod]
    gn = g.name
    K = length(g.cost_segments)
    T = model[:instance].time

    # Gar1962.ProdVars
    prod_above = model[:prod_above]

    # Gar1962.StatusVars
    is_on = model[:is_on]
    switch_on = model[:switch_on]
    switch_off = model[:switch_off]

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
                eq_segprod_limit_a[sc.name, gn, t, k] = @constraint(
                    model,
                    segprod[sc.name, gn, t, k] <=
                    g.cost_segments[k].mw[t] * is_on[gn, t] -
                    Cv * switch_on[gn, t] -
                    (t < T ? Cw * switch_off[gn, t+1] : 0.0)
                )
            else
                # Equation (47a)/(48a) in Kneuven et al. (2020)
                eq_segprod_limit_b[sc.name, gn, t, k] = @constraint(
                    model,
                    segprod[sc.name, gn, t, k] <=
                    g.cost_segments[k].mw[t] * is_on[gn, t] -
                    Cv * switch_on[gn, t] -
                    (t < T ? max(0, Cv - Cw) * switch_off[gn, t+1] : 0.0)
                )

                # Equation (47b)/(48b) in Kneuven et al. (2020)
                eq_segprod_limit_c[sc.name, gn, t, k] = @constraint(
                    model,
                    segprod[sc.name, gn, t, k] <=
                    g.cost_segments[k].mw[t] * is_on[gn, t] -
                    max(0, Cw - Cv) * switch_on[gn, t] -
                    (t < T ? Cw * switch_off[gn, t+1] : 0.0)
                )
            end

            # Definition of production
            # Equation (43) in Kneuven et al. (2020)
            eq_prod_above_def[sc.name, gn, t] = @constraint(
                model,
                prod_above[sc.name, gn, t] ==
                sum(segprod[sc.name, gn, t, k] for k in 1:K)
            )

            # Objective function
            # Equation (44) in Kneuven et al. (2020)
            add_to_expression!(
                model[:obj],
                segprod[sc.name, gn, t, k],
                g.cost_segments[k].cost[t],
            )

            # Also add an explicit upper bound on segprod to make the solver's
            # work a bit easier
            set_upper_bound(
                segprod[sc.name, gn, t, k],
                g.cost_segments[k].mw[t],
            )
        end
    end
end
