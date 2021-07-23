# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

"""
    _add_ramp_eqs!(model, unit, formulation_prod_vars, formulation_ramping, formulation_status_vars)::Nothing

Ensure constraints on ramping are met.
Based on Arroyo and Conejo (2000).
Eqns. (24), (25) in Knueven et al. (2020).

Adds constraints identified by `ArrCon200.Ramping` to `model` using variables `Gar1962.ProdVars` and `is_on` from `Gar1962.StatusVars`.
"""
function _add_ramp_eqs!(
    model::JuMP.Model,
    g::Unit,
    formulation_prod_vars::Gar1962.ProdVars,
    formulation_ramping::ArrCon2000.Ramping,
    formulation_status_vars::Gar1962.StatusVars,
)::Nothing
    # TODO: Move upper case constants to model[:instance]
    RESERVES_WHEN_START_UP = true
    RESERVES_WHEN_RAMP_UP = true
    RESERVES_WHEN_RAMP_DOWN = true
    RESERVES_WHEN_SHUT_DOWN = true
    gn = g.name
    RU = g.ramp_up_limit
    RD = g.ramp_down_limit
    SU = g.startup_limit
    SD = g.shutdown_limit
    reserve = model[:reserve]
    eq_ramp_down = _init(model, :eq_ramp_down)
    eq_ramp_up = _init(model, :eq_ramp_up)

    # Gar1962.ProdVars
    prod_above = model[:prod_above]

    # Gar1962.StatusVars
    is_on = model[:is_on]
    switch_off = model[:switch_off]
    switch_on = model[:switch_on]

    for t in 1:model[:instance].time
        # Ramp up limit
        if t == 1
            if _is_initially_on(g)
                # min power is _not_ multiplied by is_on because if !is_on, then ramp up is irrelevant
                eq_ramp_up[gn, t] = @constraint(
                    model,
                    g.min_power[t] +
                    prod_above[gn, t] +
                    (RESERVES_WHEN_RAMP_UP ? reserve[gn, t] : 0.0) <=
                    g.initial_power + RU
                )
            end
        else
            max_prod_this_period =
                g.min_power[t] * is_on[gn, t] +
                prod_above[gn, t] +
                (
                    RESERVES_WHEN_START_UP || RESERVES_WHEN_RAMP_UP ?
                    reserve[gn, t] : 0.0
                )
            min_prod_last_period =
                g.min_power[t-1] * is_on[gn, t-1] + prod_above[gn, t-1]

            # Equation (24) in Knueven et al. (2020)
            eq_ramp_up[gn, t] = @constraint(
                model,
                max_prod_this_period - min_prod_last_period <=
                RU * is_on[gn, t-1] + SU * switch_on[gn, t]
            )
        end

        # Ramp down limit
        if t == 1
            if _is_initially_on(g)
                # TODO If RD < SD, or more specifically if
                #      min_power + RD < initial_power < SD
                #      then the generator should be able to shut down at time t = 1,
                #      but the constraint below will force the unit to produce power
                eq_ramp_down[gn, t] = @constraint(
                    model,
                    g.initial_power - (g.min_power[t] + prod_above[gn, t]) <= RD
                )
            end
        else
            max_prod_last_period =
                g.min_power[t-1] * is_on[gn, t-1] +
                prod_above[gn, t-1] +
                (
                    RESERVES_WHEN_SHUT_DOWN || RESERVES_WHEN_RAMP_DOWN ?
                    reserve[gn, t-1] : 0.0
                )
            min_prod_this_period =
                g.min_power[t] * is_on[gn, t] + prod_above[gn, t]

            # Equation (25) in Knueven et al. (2020)
            eq_ramp_down[gn, t] = @constraint(
                model,
                max_prod_last_period - min_prod_this_period <=
                RD * is_on[gn, t] + SD * switch_off[gn, t]
            )
        end
    end
end
