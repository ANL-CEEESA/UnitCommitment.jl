# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

"""
    _add_unit!(model::JuMP.Model, g::Unit, formulation::Formulation)

Add production, reserve, startup, shutdown, and status variables,
and constraints for min uptime/downtime, net injection, production, ramping, startup, shutdown, and status.

Fix variables if a certain generator _must_ run or if a generator provides spinning reserves.
Also, add overflow penalty to objective for each transmission line.
"""
function _add_unit!(model::JuMP.Model, g::Unit, formulation::Formulation)
    if !all(g.must_run) && any(g.must_run)
        error("Partially must-run units are not currently supported")
    end
    if g.initial_power === nothing || g.initial_status === nothing
        error("Initial conditions for $(g.name) must be provided")
    end

    # Variables
    _add_production_vars!(model, g, formulation.prod_vars)
    _add_reserve_vars!(model, g)
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
    _add_shutdown_cost_eqs!(model, g)
    _add_startup_shutdown_limit_eqs!(model, g)
    _add_status_eqs!(model, g, formulation.status_vars)
    return
end

_is_initially_on(g::Unit)::Float64 = (g.initial_status > 0 ? 1.0 : 0.0)

"""
    _add_reserve_vars!(model::JuMP.Model, g::Unit)::Nothing

Add `:reserve` variable to `model`, fixed to zero if no spinning reserves specified.
"""
function _add_reserve_vars!(model::JuMP.Model, g::Unit, ALWAYS_CREATE_VARS = false)::Nothing
    reserve = _init(model, :reserve)
    reserve_shortfall = _init(model, :reserve_shortfall) # for accounting for shortfall penalty in the objective
    for t in 1:model[:instance].time
        if g.provides_spinning_reserves[t]
            reserve[g.name, t] = @variable(model, lower_bound = 0)
        else
            if ALWAYS_CREATE_VARS
                reserve[g.name, t] = @variable(model, lower_bound = 0)
                fix(reserve[g.name, t], 0.0; force = true)
            else
                reserve[g.name, t] = 0.0
            end
        end
    end
    return
end

"""
    _add_reserve_eqs!(model::JuMP.Model, g::Unit)::Nothing
"""
function _add_reserve_eqs!(model::JuMP.Model, g::Unit)::Nothing
    # nothing to do here
    return
end

"""
    _add_startup_shutdown_vars!(model::JuMP.Model, g::Unit)::Nothing

Add `startup` to model.
"""
function _add_startup_shutdown_vars!(model::JuMP.Model, g::Unit)::Nothing
    startup = _init(model, :startup)
    for t in 1:model[:instance].time
        for s in 1:length(g.startup_categories)
            startup[g.name, t, s] = @variable(model, binary = true)
        end
    end
    return
end

"""
    _add_startup_shutdown_limit_eqs!(model::JuMP.Model, g::Unit)::Nothing

Variables
---
* :is_on
* :prod_above
* :reserve
* :switch_on
* :switch_off

Constraints
---
* :eq_startup_limit
* :eq_shutdown_limit
"""
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
            # TODO check what happens with these variables when exporting the model
            # Generator producing too much to be turned off in the first time period
            # (can a binary variable have bounds x = 0?)
            #eqs.shutdown_limit[gi, 0] = @constraint(mip, vars.switch_off[gi, 1] <= 0)
            fix(model.vars.switch_off[gi, 1], 0.; force = true)
            #eq_shutdown_limit[g.name, 0] =
                #@constraint(model, switch_off[g.name, 1] <= 0)
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

"""
    _add_shutdown_cost_eqs!

Variables
---
* :switch_off
"""
function _add_shutdown_cost_eqs!(model::JuMP.Modle, g::Unit)::Nothing
    T = model[:instance].time
    gi = g.name
    for t = 1:T
      shutdown_cost = 0.
      if shutdown_cost > 1e-7
        # Equation (62) in Kneuven et al. (2020)
        add_to_expression!(model[:obj],
                           model[:switch_off][gi, t],
                           shutdown_cost)
      end
    end # loop over time
end # _add_shutdown_cost_eqs!

"""
    _add_ramp_eqs!(model, unit, formulation)
"""
function _add_ramp_eqs!(
    model::JuMP.Model,
    g::Unit,
    formulation::AbstractRampingFormulation,
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

"""
    _add_min_uptime_downtime_eqs!(model::JuMP.Model, g::Unit)::Nothing

Ensure constraints on up/down time are met.
Based on Garver (1962), Malkin (2003), and Rajan and Takritti (2005).
Eqns. (3), (4), (5) in Kneuven et al. (2020).

Variables
---
* :is_on
* :switch_off
* :switch_on


Constraints
---
* :eq_min_uptime
* :eq_min_downtime

"""
function _add_min_uptime_downtime_eqs!(model::JuMP.Model, g::Unit)::Nothing
    is_on = model[:is_on]
    switch_off = model[:switch_off]
    switch_on = model[:switch_on]
    eq_min_uptime = _init(model, :eq_min_uptime)
    eq_min_downtime = _init(model, :eq_min_downtime)
    T = model[:instance].time
    for t in 1:T
        # Minimum up-time
        # Equation (4) in Kneuven et al. (2020)
        eq_min_uptime[g.name, t] = @constraint(
            model,
            sum(switch_on[g.name, i] for i in (t-g.min_uptime+1):t if i >= 1)
            <= is_on[g.name, t]
        )

        # Minimum down-time
        # Equation (5) in Kneuven et al. (2020)
        eq_min_downtime[g.name, t] = @constraint(
            model,
            sum(switch_off[g.name, i] for i in (t-g.min_downtime+1):t if i >= 1)
            <= 1 - is_on[g.name, t]
        )
        
        # Minimum up/down-time for initial periods
        # Equations (3a) and (3b) in Kneuven et al. (2020)
        # (using :switch_on and :switch_off instead of :is_on)
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

"""
    _add_net_injection_eqs!(model::JuMP.Model, g::Unit)::Nothing
"""
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
