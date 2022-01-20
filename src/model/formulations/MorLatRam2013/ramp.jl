# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

function _add_ramp_eqs!(
    model::JuMP.Model,
    g::Unit,
    formulation_prod_vars::Gar1962.ProdVars,
    formulation_ramping::MorLatRam2013.Ramping,
    formulation_status_vars::Gar1962.StatusVars,
)::Nothing
    # TODO: Move upper case constants to model[:instance]
    RESERVES_WHEN_START_UP = true
    RESERVES_WHEN_RAMP_UP = true
    RESERVES_WHEN_RAMP_DOWN = true
    RESERVES_WHEN_SHUT_DOWN = true
    is_initially_on = (g.initial_status > 0)
    SU = g.startup_limit
    SD = g.shutdown_limit
    RU = g.ramp_up_limit
    RD = g.ramp_down_limit
    gn = g.name
    eq_ramp_down = _init(model, :eq_ramp_down)
    eq_ramp_up = _init(model, :eq_str_ramp_up)
    reserve = _total_reserves(model, g)

    # Gar1962.ProdVars
    prod_above = model[:prod_above]

    # Gar1962.StatusVars
    is_on = model[:is_on]
    switch_off = model[:switch_off]
    switch_on = model[:switch_on]

    for t in 1:model[:instance].time
        time_invariant =
            (t > 1) ? (abs(g.min_power[t] - g.min_power[t-1]) < 1e-7) : true

        # Ramp up limit
        if t == 1
            if is_initially_on
                eq_ramp_up[gn, t] = @constraint(
                    model,
                    g.min_power[t] +
                    prod_above[gn, t] +
                    (RESERVES_WHEN_RAMP_UP ? reserve[t] : 0.0) <=
                    g.initial_power + RU
                )
            end
        else
            # amk: without accounting for time-varying min power terms,
            #      we might get an infeasible schedule, e.g. if min_power[t-1] = 0, min_power[t] = 10
            #      and ramp_up_limit = 5, the constraint (p'(t) + r(t) <= p'(t-1) + RU)
            #      would be satisfied with p'(t) = r(t) = p'(t-1) = 0
            #      Note that if switch_on[t] = 1, then eqns (20) or (21) go into effect
            if !time_invariant
                # Use equation (24) instead
                SU = g.startup_limit
                max_prod_this_period =
                    g.min_power[t] * is_on[gn, t] +
                    prod_above[gn, t] +
                    (
                        RESERVES_WHEN_START_UP || RESERVES_WHEN_RAMP_UP ?
                        reserve[t] : 0.0
                    )
                min_prod_last_period =
                    g.min_power[t-1] * is_on[gn, t-1] + prod_above[gn, t-1]
                eq_ramp_up[gn, t] = @constraint(
                    model,
                    max_prod_this_period - min_prod_last_period <=
                    RU * is_on[gn, t-1] + SU * switch_on[gn, t]
                )
            else
                # Equation (26) in Kneuven et al. (2020)
                # TODO: what if RU < SU? places too stringent upper bound
                # prod_above[gn, t] when starting up, and creates diff with (24).
                eq_ramp_up[gn, t] = @constraint(
                    model,
                    prod_above[gn, t] +
                    (RESERVES_WHEN_RAMP_UP ? reserve[t] : 0.0) -
                    prod_above[gn, t-1] <= RU
                )
            end
        end

        # Ramp down limit
        if t == 1
            if is_initially_on
                # TODO If RD < SD, or more specifically if
                #        min_power + RD < initial_power < SD
                #      then the generator should be able to shut down at time t = 1,
                #      but the constraint below will force the unit to produce power
                eq_ramp_down[gn, t] = @constraint(
                    model,
                    g.initial_power - (g.min_power[t] + prod_above[gn, t]) <= RD
                )
            end
        else
            # amk: similar to ramp_up, need to account for time-dependent min_power
            if !time_invariant
                # Revert to (25)
                SD = g.shutdown_limit
                max_prod_last_period =
                    g.min_power[t-1] * is_on[gn, t-1] +
                    prod_above[gn, t-1] +
                    (
                        RESERVES_WHEN_SHUT_DOWN || RESERVES_WHEN_RAMP_DOWN ?
                        reserve[t-1] : 0.0
                    )
                min_prod_this_period =
                    g.min_power[t] * is_on[gn, t] + prod_above[gn, t]
                eq_ramp_down[gn, t] = @constraint(
                    model,
                    max_prod_last_period - min_prod_this_period <=
                    RD * is_on[gn, t] + SD * switch_off[gn, t]
                )
            else
                # Equation (27) in Kneuven et al. (2020)
                # TODO: Similar to above, what to do if shutting down in time t
                # and RD < SD? There is a difference with (25).
                eq_ramp_down[gn, t] = @constraint(
                    model,
                    prod_above[gn, t-1] +
                    (RESERVES_WHEN_RAMP_DOWN ? reserve[t-1] : 0.0) -
                    prod_above[gn, t] <= RD
                )
            end
        end
    end
end
