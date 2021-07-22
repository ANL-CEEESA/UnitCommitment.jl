# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

"""
    _add_startup_shutdown_limit_eqs!(model::JuMP.Model, g::Unit)::Nothing

Startup and shutdown limits from Gentile et al. (2017).
Eqns. (20), (23a), and (23b) in Kneuven et al. (2020).

Variables
---
* :is_on
* :prod_above
* :reserve
* :switch_on
* :switch_off

Constraints
---
* :eq_startstop_limit
* :eq_startup_limit
* :eq_shutdown_limit
"""
function _add_startup_shutdown_limit_eqs!(model::JuMP.Model, g::Unit)::Nothing
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

    if g.initial_power > g.shutdown_limit
        #eqs.shutdown_limit[gi, 0] = @constraint(mip, vars.switch_off[gi, 1] <= 0)
        fix(switch_off[gi, 1], 0.0; force = true)
    end

    for t in 1:T
        ## 2020-10-09 amk: added eqn (20) and check of g.min_uptime
        # Not present in (23) in Kneueven et al.
        if g.min_uptime > 1
            # Equation (20) in Kneuven et al. (2020)
            eqs.startstop_limit[gi, t] = @constraint(
                model,
                prod_above[gi, t] + reserve[gi, t] <=
                (g.max_power[t] - g.min_power[t]) * is_on[gi, t] -
                max(0, g.max_power[t] - g.startup_limit) * switch_on[gi, t] - (
                    t < T ?
                    max(0, g.max_power[t] - g.shutdown_limit) *
                    switch_off[gi, t+1] : 0.0
                )
            )
        else
            ## Startup limits
            # Equation (23a) in Kneuven et al. (2020)
            eqs.startup_limit[gi, t] = @constraint(
                model,
                prod_above[gi, t] + reserve[gi, t] <=
                (g.max_power[t] - g.min_power[t]) * is_on[gi, t] -
                max(0, g.max_power[t] - g.startup_limit) * switch_on[gi, t] - (
                    t < T ?
                    max(0, g.startup_limit - g.shutdown_limit) *
                    switch_off[gi, t+1] : 0.0
                )
            )

            ## Shutdown limits
            if t < T
                # Equation (23b) in Kneuven et al. (2020)
                eqs.shutdown_limit[gi, t] = @constraint(
                    model,
                    prod_above[gi, t] + reserve[gi, t] <=
                    (g.max_power[t] - g.min_power[t]) * xis_on[gi, t] - (
                        t < T ?
                        max(0, g.max_power[t] - g.shutdown_limit) *
                        switch_off[gi, t+1] : 0.0
                    ) -
                    max(0, g.shutdown_limit - g.startup_limit) *
                    switch_on[gi, t]
                )
            end
        end # check if g.min_uptime > 1
    end # loop over time
end # _add_startup_shutdown_limit_eqs!
