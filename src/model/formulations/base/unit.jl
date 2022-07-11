# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

function _add_unit!(model::JuMP.Model, g::Unit, formulation::Formulation)
    if !all(g.must_run) && any(g.must_run)
        error("Partially must-run units are not currently supported")
    end
    if g.initial_power === nothing || g.initial_status === nothing
        error("Initial conditions for $(g.name) must be provided")
    end

    # Variables
    _add_production_vars!(model, g, formulation.prod_vars)
    _add_spinning_reserve_vars!(model, g)
    _add_flexiramp_reserve_vars!(model, g)
    _add_startup_shutdown_vars!(model, g)
    _add_status_vars!(model, g, formulation.status_vars)

    # Constraints and objective function
    _add_min_uptime_downtime_eqs!(model, g)
    _add_net_injection_eqs!(model, g)
    _add_production_limit_eqs!(model, g, formulation.prod_vars)
    _add_production_piecewise_linear_eqs!(
        model,
        g,
        formulation.prod_vars,
        formulation.pwl_costs,
        formulation.status_vars,
    )
    _add_ramp_eqs!(
        model,
        g,
        formulation.prod_vars,
        formulation.ramping,
        formulation.status_vars,
    )
    _add_startup_cost_eqs!(model, g, formulation.startup_costs)
    _add_startup_shutdown_limit_eqs!(model, g)
    _add_status_eqs!(model, g, formulation.status_vars)
    return
end

_is_initially_on(g::Unit)::Float64 = (g.initial_status > 0 ? 1.0 : 0.0)

function _add_spinning_reserve_vars!(model::JuMP.Model, g::Unit)::Nothing
    reserve = _init(model, :reserve)
    reserve_shortfall = _init(model, :reserve_shortfall)
    for r in g.reserves
        r.type == "spinning" || continue
        for t in 1:model[:instance].time
            reserve[r.name, g.name, t] = @variable(model, lower_bound = 0)
            if (r.name, t) ∉ keys(reserve_shortfall)
                reserve_shortfall[r.name, t] = @variable(model, lower_bound = 0)
                if r.shortfall_penalty < 0
                    set_upper_bound(reserve_shortfall[r.name, t], 0.0)
                end
            end
        end
    end
    return
end

function _add_flexiramp_reserve_vars!(model::JuMP.Model, g::Unit)::Nothing
    upflexiramp = _init(model, :upflexiramp)
    upflexiramp_shortfall = _init(model, :upflexiramp_shortfall)
    mfg = _init(model, :mfg)
    dwflexiramp = _init(model, :dwflexiramp)
    dwflexiramp_shortfall = _init(model, :dwflexiramp_shortfall)
    for r in g.reserves
        r.type == "flexiramp" || continue
        for t in 1:model[:instance].time
            # maximum feasible generation, \bar{g_{its}} in Wang & Hobbs (2016)
            mfg[r.name, g.name, t] = @variable(model, lower_bound = 0)
            upflexiramp[r.name, g.name, t] = @variable(model) # up-flexiramp, ur_{it} in Wang & Hobbs (2016)
            dwflexiramp[r.name, g.name, t] = @variable(model) # down-flexiramp, dr_{it} in Wang & Hobbs (2016)
            if (r.name, t) ∉ keys(upflexiramp_shortfall)
                upflexiramp_shortfall[r.name, t] =
                    @variable(model, lower_bound = 0)
                dwflexiramp_shortfall[r.name, t] =
                    @variable(model, lower_bound = 0)
                if r.shortfall_penalty < 0
                    set_upper_bound(upflexiramp_shortfall[r.name, t], 0.0)
                    set_upper_bound(dwflexiramp_shortfall[r.name, t], 0.0)
                end
            end
        end
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
    reserve = _total_reserves(model, g)
    switch_off = model[:switch_off]
    switch_on = model[:switch_on]
    T = model[:instance].time
    for t in 1:T
        # Startup limit
        eq_startup_limit[g.name, t] = @constraint(
            model,
            prod_above[g.name, t] + reserve[t] <=
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

function _add_ramp_eqs!(
    model::JuMP.Model,
    g::Unit,
    formulation::RampingFormulation,
)::Nothing
    prod_above = model[:prod_above]
    reserve = _total_reserves(model, g)
    eq_ramp_up = _init(model, :eq_ramp_up)
    eq_ramp_down = _init(model, :eq_ramp_down)
    for t in 1:model[:instance].time
        # Ramp up limit 
        if t == 1
            if _is_initially_on(g) == 1
                eq_ramp_up[g.name, t] = @constraint(
                    model,
                    prod_above[g.name, t] + reserve[t] <=
                    (g.initial_power - g.min_power[t]) + g.ramp_up_limit
                )
            end
        else
            eq_ramp_up[g.name, t] = @constraint(
                model,
                prod_above[g.name, t] + reserve[t] <=
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
    end
end

function _total_reserves(model, g)::Vector
    T = model[:instance].time
    reserve = [0.0 for _ in 1:T]
    spinning_reserves = [r for r in g.reserves if r.type == "spinning"]
    if !isempty(spinning_reserves)
        reserve += [
            sum(model[:reserve][r.name, g.name, t] for r in spinning_reserves) for t in 1:model[:instance].time
        ]
    end
    return reserve
end
