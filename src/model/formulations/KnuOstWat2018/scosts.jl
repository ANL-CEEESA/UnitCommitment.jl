# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

"""
    _add_startup_cost_eqs!

Extended formulation of startup costs using indicator variables
based on Kneuven, Ostrowski, and Watson, 2020
--- equations (59), (60), (61).

Variables
---
* switch_on
* switch_off
* downtime_arc

Constraints
---
* eq_startup_at_t
* eq_shutdown_at_t
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
    gn = g.name

    _init(model, eq_startup_at_t)
    _init(model, eq_shutdown_at_t)

    switch_on = model[:switch_on]
    switch_off = model[:switch_off]
    downtime_arc = model[:downtime_arc]

    DT = g.min_downtime # minimum time offline
    TC = g.startup_categories[S].delay # time offline until totally cold

    # If initial_status < 0, then this is the amount of time the generator has been off
    initial_time_shutdown = (g.initial_status < 0 ? -g.initial_status : 0)

    for t in 1:model[:instance].time
        # Fix to zero values of downtime_arc outside the feasible time pairs
        # Specifically, x(t,t') = 0 if t' does not belong to 𝒢 = [t+DT, t+TC-1]
        # This is because DT is the minimum downtime, so there is no way x(t,t')=1 for t'<t+DT
        # and TC is the "time until cold" => if the generator starts afterwards, always has max cost
        #start_time = min(t + DT, T)
        #end_time = min(t + TC - 1, T)
        #for tmp_t in t+1:start_time
        #  fix(vars.downtime_arc[gn, t, tmp_t], 0.; force = true)
        #end
        #for tmp_t in end_time+1:T
        #  fix(vars.downtime_arc[gn, t, tmp_t], 0.; force = true)
        #end

        # Equation (59) in Kneuven et al. (2020)
        # Relate downtime_arc with switch_on
        # "switch_on[g,t] >= x_g(t',t) for all t' \in [t-TC+1, t-DT]"
        eq_startup_at_t[gn, t] =
            @constraint(model,
                        switch_on[gn, t]
                        >= sum(downtime_arc[gn,tmp_t,t]
                            for tmp_t in t-TC+1:t-DT if tmp_t >= 1)
                    )

        # Equation (60) in Kneuven et al. (2020)
        # "switch_off[g,t] >= x_g(t,t') for all t' \in [t+DT, t+TC-1]"
        eqs.shutdown_at_t[gn, t] =
            @constraint(model,
                        switch_off[gn, t]
                        >= sum(downtime_arc[gn,t,tmp_t]
                            for tmp_t in t+DT:t+TC-1 if tmp_t <= T)
                    )

        # Objective function terms for start-up costs
        # Equation (61) in Kneuven et al. (2020)
        default_category = S
        if initial_time_shutdown > 0 && t + initial_time_shutdown - 1 < TC
            for s in 1:S-1
            # If off for x periods before, then belongs to category s
            # if -x+1 in [t-delay[s+1]+1,t-delay[s]]
            # or, equivalently, if total time off in [delay[s], delay[s+1]-1]
            # where total time off = t - 1 + initial_time_shutdown
            # (the -1 because not off for current time period)
            if t + initial_time_shutdown - 1 < g.startup_categories[s+1].delay
                default_category = s
                break # does not go into next category
            end
            end
        end
        add_to_expression!(model[:obj],
                            switch_on[gn, t],
                            g.startup_categories[default_category].cost)

        for s in 1:S-1
            # Objective function terms for start-up costs
            # Equation (61) in Kneuven et al. (2020)
            # Says to replace the cost of last category with cost of category s
            start_range = max((t - g.startup_categories[s + 1].delay + 1),1)
            end_range = min((t - g.startup_categories[s].delay),T-1)
            for tmp_t in start_range:end_range
            if (t < tmp_t + DT) || (t >= tmp_t + TC) # the second clause should never be true for s < S
                continue
            end
            add_to_expression!(model[:obj],
                                downtime_arc[gn,tmp_t,t],
                                g.startup_categories[s].cost - g.startup_categories[S].cost)
            end
        end # iterate over startup categories
    end # iterate over time
end # add_startup_costs_KneOstWat20