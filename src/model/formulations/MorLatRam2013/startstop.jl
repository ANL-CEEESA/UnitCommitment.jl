# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

"""
    _add_startup_shutdown_limit_eqs!(model::JuMP.Model, g::Unit)::Nothing

Startup and shutdown limits from Morales-España et al. (2013a).
Eqns. (20), (21a), and (21b) in Knueven et al. (2020).

Uses variable `prod_above` from `Gar1962.ProdVars`, the variables in `Gar1962.StatusVars`, and `reserve`
to generate constraints below.

Constraints
---
* :eq_startstop_limit
* :eq_startup_limit
* :eq_shutdown_limit
"""
function _add_startup_shutdown_limit_eqs!(
    model::JuMP.Model,
    g::Unit,
    formulation_status_vars::Gar1962.StatusVars,
    formulation_prod_vars::Gar1962.ProdVars,
)::Nothing
    # TODO: Move upper case constants to model[:instance]
    RESERVES_WHEN_START_UP = true
    RESERVES_WHEN_RAMP_UP = true
    RESERVES_WHEN_RAMP_DOWN = true
    RESERVES_WHEN_SHUT_DOWN = true

    eq_startstop_limit = _init(model, :eq_startstop_limit)
    eq_shutdown_limit = _init(model, :eq_shutdown_limit)
    eq_startup_limit = _init(model, :eq_startup_limit)

    is_on = model[:is_on]
    prod_above = model[:prod_above]
    reserve = model[:reserve]
    switch_off = model[:switch_off]
    switch_on = model[:switch_on]

    T = model[:instance].time
    gi = g.name
    for t in 1:T
        ## 2020-10-09 amk: added eqn (20) and check of g.min_uptime
        if g.min_uptime > 1 && t < T
            # Equation (20) in Knueven et al. (2020)
            # UT > 1 required, to guarantee that vars.switch_on[gi, t] and vars.switch_off[gi, t+1] are not both = 1 at the same time
            eq_startstop_limit[gi, t] = @constraint(
                model,
                prod_above[gi, t] + reserve[gi, t] <=
                (g.max_power[t] - g.min_power[t]) * is_on[gi, t] -
                max(0, g.max_power[t] - g.startup_limit) * switch_on[gi, t] -
                max(0, g.max_power[t] - g.shutdown_limit) * switch_off[gi, t+1]
            )
        else
            ## Startup limits
            # Equation (21a) in Knueven et al. (2020)
            # Proposed by Morales-España et al. (2013a)
            eqs_startup_limit[gi, t] = @constraint(
                model,
                prod_above[gi, t] + reserve[gi, t] <=
                (g.max_power[t] - g.min_power[t]) * is_on[gi, t] -
                max(0, g.max_power[t] - g.startup_limit) * switch_on[gi, t]
            )

            ## Shutdown limits
            if t < T
                # Equation (21b) in Knueven et al. (2020)
                # TODO different from what was in previous model, due to reserve variable
                # ax: ideally should have reserve_up and reserve_down variables
                #     i.e., the generator should be able to increase/decrease production as specified
                #     (this is a heuristic for a "robust" solution,
                #     in case there is an outage or a surge, and flow has to be redirected)
                # amk: if shutdown_limit is the max prod of generator in time period before shutting down,
                #      then it makes sense to count reserves, because otherwise, if reserves ≠ 0,
                #      then the generator will actually produce more than the limit
                eqs.shutdown_limit[gi, t] = @constraint(
                    model,
                    prod_above[gi, t] +
                    (RESERVES_WHEN_SHUT_DOWN ? reserve[gi, t] : 0.0) <=
                    (g.max_power[t] - g.min_power[t]) * is_on[gi, t] -
                    max(0, g.max_power[t] - g.shutdown_limit) *
                    switch_off[gi, t+1]
                )
            end
        end
    end
end
