# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using JuMP

function _add_thermal_units!(
    model::JuMP.Model,
    instance::UnitCommitmentInstance,
    formulation::Formulation,
)::Nothing
    _add_thermal_vars!(model, instance)
    _add_thermal_obj!(model, instance)
    _add_thermal_constr_status!(model, instance)
    _add_thermal_constr_startup!(model, instance)
    _add_thermal_constr_pwl_costs!(model, instance, formulation.pwl_costs)
    _add_thermal_constr_ramping!(model, instance, formulation.ramping)
    _add_thermal_constr_slimits!(model, instance, formulation.slimits)
    return
end

function _add_thermal_vars!(
    model::JuMP.Model,
    instance::UnitCommitmentInstance,
)::Nothing
    T = instance.time
    is_on = _init(model, :is_on)
    switch_on = _init(model, :switch_on)
    switch_off = _init(model, :switch_off)
    startup = _init(model, :startup)
    invest = _init(model, :invest)
    prod_above = _init(model, :prod_above)
    segprod = _init(model, :segprod)
    reserve = _init(model, :reserve)
    reserve_shortfall = _init(model, :reserve_shortfall)

    for t in 1:T
        # First stage
        for g in instance.scenarios[1].thermal_units
            # Status variables
            is_on[g.name, t] = @variable(model, binary = true)
            switch_on[g.name, t] = @variable(model, binary = true)
            switch_off[g.name, t] = @variable(model, binary = true)
            switch_off[g.name, T+1] = 0.0

            # Startup
            for s in 1:length(g.startup_categories)
                startup[g.name, t, s] = @variable(model, binary = true)
            end

            # Investment
            if g.invest[1] > 0.0
                invest[g.name, 0] = 0.0
                invest[g.name, t] = @variable(model, binary = true)
            end
        end

        # Second stage
        for sc in instance.scenarios
            # Spinning reserve shortfall
            for r in sc.reserves
                reserve_shortfall[sc.name, r.name, t] =
                    @variable(model, lower_bound = 0)
                if r.shortfall_penalty < 0
                    set_upper_bound(reserve_shortfall[sc.name, r.name, t], 0.0)
                end
            end

            for g in sc.thermal_units
                # Production
                for k in 1:length(g.cost_segments)
                    segprod[sc.name, g.name, t, k] = @variable(
                        model,
                        lower_bound = 0,
                        upper_bound = g.cost_segments[k].mw[t]
                    )
                end
                prod_above[sc.name, g.name, t] =
                    @variable(model, lower_bound = 0)

                # Spinning reserves
                for r in g.reserves
                    r.type == "spinning" || continue
                    reserve[sc.name, r.name, g.name, t] =
                        @variable(model, lower_bound = 0)
                end
            end
        end
    end
    return
end

function _add_thermal_obj!(
    model::JuMP.Model,
    instance::UnitCommitmentInstance,
)::Nothing
    is_on = _init(model, :is_on)
    startup = _init(model, :startup)
    invest = _init(model, :invest)
    segprod = _init(model, :segprod)
    reserve_shortfall = _init(model, :reserve_shortfall)

    # Production costs
    for t in 1:instance.time
        for g in instance.scenarios[1].thermal_units
            add_to_expression!(
                model[:obj],
                is_on[g.name, t],
                g.min_power_cost[t],
            )
        end
        for sc in instance.scenarios
            for g in sc.thermal_units
                for k in 1:length(g.cost_segments)
                    add_to_expression!(
                        model[:obj],
                        segprod[sc.name, g.name, t, k],
                        sc.probability * g.cost_segments[k].cost[t],
                    )
                end
            end
        end
    end

    # Startup costs
    for t in 1:instance.time
        for g in instance.scenarios[1].thermal_units
            for s in 1:length(g.startup_categories)
                add_to_expression!(
                    model[:obj],
                    startup[g.name, t, s],
                    g.startup_categories[s].cost,
                )
            end
        end
    end

    # Investment costs
    for g in instance.scenarios[1].thermal_units
        g.invest[1] > 0 || continue
        for t in 1:instance.time
            add_to_expression!(
                model[:obj],
                invest[g.name, t] - invest[g.name, t-1],
                g.invest[t] * instance.scenarios[1].investment_cost_weight,
            )
        end
    end

    # Spinning reserve shortfall
    for t in 1:instance.time
        for sc in instance.scenarios
            for r in sc.reserves
                r.type == "spinning" || continue
                if r.shortfall_penalty >= 0
                    add_to_expression!(
                        model[:obj],
                        r.shortfall_penalty * sc.probability,
                        reserve_shortfall[sc.name, r.name, t],
                    )
                end
            end
        end
    end
    return
end

function _add_thermal_constr_status!(
    model::JuMP.Model,
    instance::UnitCommitmentInstance,
)::Nothing
    T = instance.time
    is_on = model[:is_on]
    switch_off = model[:switch_off]
    switch_on = model[:switch_on]

    eq_binary_link = _init(model, :eq_binary_link)
    eq_commitment_status = _init(model, :eq_commitment_status)
    eq_min_downtime = _init(model, :eq_min_downtime)
    eq_min_uptime = _init(model, :eq_min_uptime)
    eq_must_run = _init(model, :eq_must_run)
    eq_switch_on_off = _init(model, :eq_switch_on_off)

    for t in 1:T, g in instance.scenarios[1].thermal_units
        # Must-run
        if g.must_run[t]
            eq_must_run[g.name, t] = @constraint(model, is_on[g.name, t] >= 1)
        end

        # Commitment status
        if g.commitment_status[t] !== nothing
            eq_commitment_status[g.name, t] = @constraint(
                model,
                is_on[g.name, t] == (g.commitment_status[t] ? 1.0 : 0.0)
            )
        end

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
    return
end

function _add_thermal_constr_startup!(
    model::JuMP.Model,
    instance::UnitCommitmentInstance,
)::Nothing
    T = instance.time
    startup = model[:startup]
    switch_off = model[:switch_off]
    switch_on = model[:switch_on]

    eq_startup_choose = _init(model, :eq_startup_choose)
    eq_startup_restrict = _init(model, :eq_startup_restrict)

    for t in 1:T
        for g in instance.scenarios[1].thermal_units
            # If unit is switching on, we must choose a startup category
            S = length(g.startup_categories)
            eq_startup_choose[g.name, t] = @constraint(
                model,
                switch_on[g.name, t] == sum(startup[g.name, t, s] for s in 1:S)
            )

            for s in 1:S
                # If unit has not switched off in the last `delay` time periods, startup category is forbidden.
                # The last startup category is always allowed.
                if s < S
                    range_start = t - g.startup_categories[s+1].delay + 1
                    range_end = t - g.startup_categories[s].delay
                    range = (range_start:range_end)
                    initial_sum = (
                        g.initial_status < 0 &&
                        (g.initial_status + 1 in range) ? 1.0 : 0.0
                    )
                    eq_startup_restrict[g.name, t, s] = @constraint(
                        model,
                        startup[g.name, t, s] <=
                        initial_sum +
                        sum(switch_off[g.name, i] for i in range if i >= 1)
                    )
                end
            end
        end
    end
    return
end

function _add_thermal_constr_pwl_costs!(
    model::JuMP.Model,
    instance::UnitCommitmentInstance,
    ::BasePwlCosts,
)::Nothing
    T = instance.time
    is_on = model[:is_on]
    prod_above = model[:prod_above]
    segprod = model[:segprod]

    eq_prod_above_def = _init(model, :eq_prod_above_def)
    eq_prod_limit = _init(model, :eq_prod_limit)

    for sc in instance.scenarios
        for g in sc.thermal_units
            K = length(g.cost_segments)
            reserve = _total_reserves(model, instance, g, sc)
            for t in 1:T
                # Production limits
                eq_prod_limit[sc.name, g.name, t] = @constraint(
                    model,
                    prod_above[sc.name, g.name, t] + reserve[t] <=
                    (g.max_power[t] - g.min_power[t]) * is_on[g.name, t]
                )

                # Break down production above into smaller segments
                eq_prod_above_def[sc.name, g.name, t] = @constraint(
                    model,
                    prod_above[sc.name, g.name, t] ==
                    sum(segprod[sc.name, g.name, t, k] for k in 1:K)
                )
            end
        end
    end
    return
end

function _total_reserves(model, instance, g, sc)::Vector
    T = instance.time
    reserve = [0.0 for _ in 1:T]
    spinning_reserves = [r for r in g.reserves if r.type == "spinning"]
    if !isempty(spinning_reserves)
        reserve += [
            sum(
                model[:reserve][sc.name, r.name, g.name, t] for
                r in spinning_reserves
            ) for t in 1:T
        ]
    end
    return reserve
end

_is_initially_on(g::ThermalUnit)::Float64 = (g.initial_status > 0 ? 1.0 : 0.0)
