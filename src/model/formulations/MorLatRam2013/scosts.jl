# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

"""
    _add_startup_cost_eqs!

Extended formulation of startup costs using indicator variables
based on Muckstadt and Wilson, 1968;
this version by Morales-España, Latorre, and Ramos, 2013.
Eqns. (54), (55), and (56) in Kneuven et al. (2020).
Note that the last 'constraint' is actually setting the objective.

\tstartup[gi,s,t] ≤ sum_{i=s.delay}^{(s+1).delay-1} switch_off[gi,t-i]
\tswitch_on[gi,t] = sum_{s=1}^{length(startup_categories)} startup[gi,s,t]
\tstartup_cost[gi,t] = sum_{s=1}^{length(startup_categories)} cost_segments[s].cost * startup[gi,s,t]

Variables
---
* startup
* switch_on
* switch_off

Constraints
---
* eq_startup_choose
* eq_startup_restrict
"""
function _add_startup_cost_eqs!(
    model::JuMP.Model,
    g::Unit,
    formulation::MorLatRam2013.StartupCosts,
)::Nothing
    S = length(g.startup_categories)
    if S == 0
        return
    end

    # Constraints created
    eq_startup_choose = _init(model, :eq_startup_choose)
    eq_startup_restrict = _init(model, :eq_startup_restrict)

    # Variables needed
    startup = model[:startup]
    switch_on = model[:switch_on]
    switch_off = model[:switch_off]

    gn = g.name
    for t in 1:model[:instance].time
        # If unit is switching on, we must choose a startup category
        # Equation (55) in Kneuven et al. (2020)
        eq_startup_choose[gn, t] = @constraint(
            model,
            switch_on[gn, t] ==
            sum(startup[gn, t, s] for s in 1:S)
        )

        for s in 1:S
            # If unit has not switched off in the last `delay` time periods, startup category is forbidden.
            # The last startup category is always allowed.
            if s < S
                range_start = t - g.startup_categories[s+1].delay + 1
                range_end = t - g.startup_categories[s].delay
                range = (range_start:range_end)
                # If initial_status < 0, then this is the amount of time the generator has been off
                initial_sum = (
                    g.initial_status < 0 && (g.initial_status + 1 in range) ? 1.0 : 0.0
                )
                # Change of index version of equation (54) in Kneuven et al. (2020):
                #   startup[gi,s,t] ≤ sum_{i=s.delay}^{(s+1).delay-1} switch_off[gi,t-i]
                eq_startup_restrict[gn, t, s] = @constraint(
                    model,
                    startup[gn, t, s] <=
                      initial_sum + sum(switch_off[gn, i] for i in range if i >= 1)
                )
            end # if s < S (not the last category)

            # Objective function terms for start-up costs
            # Equation (56) in Kneuven et al. (2020)
            add_to_expression!(
                model[:obj],
                startup[gn, t, s],
                g.startup_categories[s].cost,
            )
        end # iterate over startup categories
    end # iterate over time
    return
end
