# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

function _add_unit!(model::JuMP.Model, g::Unit, f::Formulation)
    if !all(g.must_run) && any(g.must_run)
        error("Partially must-run units are not currently supported")
    end
    if g.initial_power === nothing || g.initial_status === nothing
        error("Initial conditions for $(g.name) must be provided")
    end

    # Variables
    _add_production_vars!(model, g)
    _add_reserve_vars!(model, g)
    _add_startup_shutdown_vars!(model, g)
    _add_status_vars!(model, g)

    # Constraints and objective function
    _add_min_uptime_downtime_eqs!(model, g)
    _add_net_injection_eqs!(model, g)
    _add_production_limit_eqs!(model, g)
    _add_production_piecewise_linear_eqs!(model, g, f.pwl_costs)
    _add_ramp_eqs!(model, g, f.ramping)
    _add_startup_shutdown_costs_eqs!(model, g)
    _add_startup_shutdown_limit_eqs!(model, g)
    _add_status_eqs!(model, g)
    return
end

_is_initially_on(g::Unit)::Float64 = (g.initial_status > 0 ? 1.0 : 0.0)

function _add_production_vars!(model::JuMP.Model, g::Unit)::Nothing
    prod_above = _init(model, :prod_above)
    segprod = _init(model, :segprod)
    for t in 1:model[:instance].time
        for k in 1:length(g.cost_segments)
            segprod[g.name, t, k] = @variable(model, lower_bound = 0)
        end
        prod_above[g.name, t] = @variable(model, lower_bound = 0)
    end
    return
end

function _add_production_limit_eqs!(model::JuMP.Model, g::Unit)::Nothing
    eq_prod_limit = _init(model, :eq_prod_limit)
    is_on = model[:is_on]
    prod_above = model[:prod_above]
    reserve = model[:reserve]
    gn = g.name
    for t in 1:model[:instance].time
        # Objective function terms for production costs
        # Part of (69) of Kneuven et al. (2020) as C^R_g * u_g(t) term
        add_to_expression!(model[:obj], is_on[gn, t], g.min_power_cost[t])

        # Production limit
        # Equation (18) in Kneuven et al. (2020)
        #   as \bar{p}_g(t) \le \bar{P}_g u_g(t)
        # amk: this is a weaker version of (20) and (21) in Kneuven et al. (2020)
        #      but keeping it here in case those are not present
        power_diff = max(g.max_power[t], 0.0) - max(g.min_power[t], 0.0)
        if power_diff < 1e-7
            power_diff = 0.0
        end
        eq_prod_limit[gn, t] = @constraint(
            model,
            prod_above[gn, t] + reserve[gn, t] <= power_diff * is_on[gn, t]
        )
    end
end

function _add_reserve_vars!(model::JuMP.Model, g::Unit)::Nothing
    reserve = _init(model, :reserve)
    for t in 1:model[:instance].time
        if g.provides_spinning_reserves[t]
            reserve[g.name, t] = @variable(model, lower_bound = 0)
        else
            reserve[g.name, t] = 0.0
        end
    end
    return
end

function _add_reserve_eqs!(model::JuMP.Model, g::Unit)::Nothing
    reserve = model[:reserve]
    for t in 1:model[:instance].time
        add_to_expression!(expr_reserve[g.bus.name, t], reserve[g.name, t], 1.0)
    end
    return
end

function _add_startup_shutdown_vars!(model::JuMP.Model, g::Unit)::Nothing
    startup = _init(model, :startup)
    for t in 1:model[:instance].time
        for s in 1:length(g.startup_categories)
            startup[g.name, t, s] = @variable(model, binary = true)
        end
    end
    return
end

function _add_startup_shutdown_limit_eqs!(model::JuMP.Model, g::Unit)::Nothing
    eq_shutdown_limit = _init(model, :eq_shutdown_limit)
    eq_startup_limit = _init(model, :eq_startup_limit)
    is_on = model[:is_on]
    prod_above = model[:prod_above]
    reserve = model[:reserve]
    switch_off = model[:switch_off]
    switch_on = model[:switch_on]
    T = model[:instance].time
    for t in 1:T
        # Startup limit
        eq_startup_limit[g.name, t] = @constraint(
            model,
            prod_above[g.name, t] + reserve[g.name, t] <=
            (g.max_power[t] - g.min_power[t]) * is_on[g.name, t] -
            max(0, g.max_power[t] - g.startup_limit) * switch_on[g.name, t]
        )
        # Shutdown limit
        if g.initial_power > g.shutdown_limit
            eq_shutdown_limit[g.name, 0] =
                @constraint(model, switch_off[g.name, 1] <= 0)
        end
        if t < T
            eq_shutdown_limit[g.name, t] = @constraint(
                model,
                prod_above[g.name, t] <=
                (g.max_power[t] - g.min_power[t]) * is_on[g.name, t] -
                max(0, g.max_power[t] - g.shutdown_limit) *
                switch_off[g.name, t+1]
            )
        end
    end
    return
end

function _add_startup_shutdown_costs_eqs!(model::JuMP.Model, g::Unit)::Nothing
    eq_startup_choose = _init(model, :eq_startup_choose)
    eq_startup_restrict = _init(model, :eq_startup_restrict)
    S = length(g.startup_categories)
    startup = model[:startup]
    for t in 1:model[:instance].time
        for s in 1:S
            # If unit is switching on, we must choose a startup category
            eq_startup_choose[g.name, t, s] = @constraint(
                model,
                model[:switch_on][g.name, t] ==
                sum(startup[g.name, t, s] for s in 1:S)
            )

            # If unit has not switched off in the last `delay` time periods, startup category is forbidden.
            # The last startup category is always allowed.
            if s < S
                range_start = t - g.startup_categories[s+1].delay + 1
                range_end = t - g.startup_categories[s].delay
                range = (range_start:range_end)
                initial_sum = (
                    g.initial_status < 0 && (g.initial_status + 1 in range) ? 1.0 : 0.0
                )
                eq_startup_restrict[g.name, t, s] = @constraint(
                    model,
                    startup[g.name, t, s] <=
                    initial_sum + sum(
                        model[:switch_off][g.name, i] for i in range if i >= 1
                    )
                )
            end

            # Objective function terms for start-up costs
            add_to_expression!(
                model[:obj],
                startup[g.name, t, s],
                g.startup_categories[s].cost,
            )
        end
    end
    return
end

function _add_status_vars!(model::JuMP.Model, g::Unit)::Nothing
    is_on = _init(model, :is_on)
    switch_on = _init(model, :switch_on)
    switch_off = _init(model, :switch_off)
    for t in 1:model[:instance].time
        if g.must_run[t]
            is_on[g.name, t] = 1.0
            switch_on[g.name, t] = (t == 1 ? 1.0 - _is_initially_on(g) : 0.0)
            switch_off[g.name, t] = 0.0
        else
            is_on[g.name, t] = @variable(model, binary = true)
            switch_on[g.name, t] = @variable(model, binary = true)
            switch_off[g.name, t] = @variable(model, binary = true)
        end
    end
    return
end

function _add_status_eqs!(model::JuMP.Model, g::Unit)::Nothing
    eq_binary_link = _init(model, :eq_binary_link)
    eq_switch_on_off = _init(model, :eq_switch_on_off)
    is_on = model[:is_on]
    switch_off = model[:switch_off]
    switch_on = model[:switch_on]
    for t in 1:model[:instance].time
        if !g.must_run[t]
            # Link binary variables
            if t == 1
                eq_binary_link[g.name, t] = @constraint(
                    model,
                    is_on[g.name, t] - _is_initially_on(g) ==
                    switch_on[g.name, t] - switch_off[g.name, t]
                )
            else
                eq_binary_link[g.name, t] = @constraint(
                    model,
                    is_on[g.name, t] - is_on[g.name, t-1] ==
                    switch_on[g.name, t] - switch_off[g.name, t]
                )
            end
            # Cannot switch on and off at the same time
            eq_switch_on_off[g.name, t] = @constraint(
                model,
                switch_on[g.name, t] + switch_off[g.name, t] <= 1
            )
        end
    end
    return
end

function _add_ramp_eqs!(
    model::JuMP.Model,
    g::Unit,
    formulation::RampingFormulation,
)::Nothing
    prod_above = model[:prod_above]
    reserve = model[:reserve]
    eq_ramp_up = _init(model, :eq_ramp_up)
    eq_ramp_down = _init(model, :eq_ramp_down)
    for t in 1:model[:instance].time
        # Ramp up limit
        if t == 1
            if _is_initially_on(g) == 1
                eq_ramp_up[g.name, t] = @constraint(
                    model,
                    prod_above[g.name, t] + reserve[g.name, t] <=
                    (g.initial_power - g.min_power[t]) + g.ramp_up_limit
                )
            end
        else
            eq_ramp_up[g.name, t] = @constraint(
                model,
                prod_above[g.name, t] + reserve[g.name, t] <=
                prod_above[g.name, t-1] + g.ramp_up_limit
            )
        end

        # Ramp down limit
        if t == 1
            if _is_initially_on(g) == 1
                eq_ramp_down[g.name, t] = @constraint(
                    model,
                    prod_above[g.name, t] >=
                    (g.initial_power - g.min_power[t]) - g.ramp_down_limit
                )
            end
        else
            eq_ramp_down[g.name, t] = @constraint(
                model,
                prod_above[g.name, t] >=
                prod_above[g.name, t-1] - g.ramp_down_limit
            )
        end
    end
end

function _add_min_uptime_downtime_eqs!(model::JuMP.Model, g::Unit)::Nothing
    is_on = model[:is_on]
    switch_off = model[:switch_off]
    switch_on = model[:switch_on]
    eq_min_uptime = _init(model, :eq_min_uptime)
    eq_min_downtime = _init(model, :eq_min_downtime)
    T = model[:instance].time
    for t in 1:T
        # Minimum up-time
        eq_min_uptime[g.name, t] = @constraint(
            model,
            sum(switch_on[g.name, i] for i in (t-g.min_uptime+1):t if i >= 1) <= is_on[g.name, t]
        )
        # Minimum down-time
        eq_min_downtime[g.name, t] = @constraint(
            model,
            sum(
                switch_off[g.name, i] for i in (t-g.min_downtime+1):t if i >= 1
            ) <= 1 - is_on[g.name, t]
        )
        # Minimum up/down-time for initial periods
        if t == 1
            if g.initial_status > 0
                eq_min_uptime[g.name, 0] = @constraint(
                    model,
                    sum(
                        switch_off[g.name, i] for
                        i in 1:(g.min_uptime-g.initial_status) if i <= T
                    ) == 0
                )
            else
                eq_min_downtime[g.name, 0] = @constraint(
                    model,
                    sum(
                        switch_on[g.name, i] for
                        i in 1:(g.min_downtime+g.initial_status) if i <= T
                    ) == 0
                )
            end
        end
    end
end

function _add_net_injection_eqs!(model::JuMP.Model, g::Unit)::Nothing
    expr_net_injection = model[:expr_net_injection]
    for t in 1:model[:instance].time
        # Add to net injection expression
        add_to_expression!(
            expr_net_injection[g.bus.name, t],
            model[:prod_above][g.name, t],
            1.0,
        )
        add_to_expression!(
            expr_net_injection[g.bus.name, t],
            model[:is_on][g.name, t],
            g.min_power[t],
        )
        # Add to reserves expression
        add_to_expression!(
            model[:expr_reserve][g.bus.name, t],
            model[:reserve][g.name, t],
            1.0,
        )
    end
end
