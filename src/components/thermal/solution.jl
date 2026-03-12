# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

function store_solution(
    sol::AbstractDict,
    model::UnitCommitmentModel,
    ::ThermalExt,
)::Nothing
    instance = model.instance
    T = instance.time
    for sc in instance.scenarios
        _store_thermal_solution!(sol[sc.name], model.inner, sc, T)
        _store_reserve_solution!(sol[sc.name], model.inner, sc, T)
        _store_thermal_summary!(sol[sc.name], sc, T)
    end
    return
end

function _store_thermal_summary!(sol::OrderedDict, sc, T::Int)
    thermal_units = sc[:thermal]
    summary = get!(OrderedDict, sol, "Summary")

    prod_cost = sol["Thermal: Production cost (\$)"]
    startup_cost = sol["Thermal: Startup cost (\$)"]
    shutdown_cost = sol["Thermal: Shutdown cost (\$)"]
    production = sol["Thermal: Production (MW)"]
    is_on = sol["Thermal: Is on"]
    switch_on = sol["Thermal: Switch on"]
    switch_off = sol["Thermal: Switch off"]

    # Costs
    summary["Thermal: Total production cost (\$)"] = _total(prod_cost)
    summary["Thermal: Total startup cost (\$)"] = _total(startup_cost)
    summary["Thermal: Total shutdown cost (\$)"] = _total(shutdown_cost)

    # Peak production
    prod_per_t = _per_t(production, T)
    summary["Thermal: Peak production (MW)"] = maximum(prod_per_t)

    # Peak capacity online
    cap_per_t = [
        sum(is_on[g.name][t] * g.max_power[t] for g in thermal_units)
        for t in 1:T
    ]
    summary["Thermal: Peak capacity online (MW)"] = maximum(cap_per_t)

    # Average utilization (production / online capacity)
    total_prod = sum(prod_per_t)
    total_cap = sum(cap_per_t)
    if total_cap > 0
        summary["Thermal: Average utilization (%)"] =
            100.0 * total_prod / total_cap
    end

    # Startups & shutdowns
    summary["Thermal: Total startups"] = round(Int, _total(switch_on))
    summary["Thermal: Total shutdowns"] = round(Int, _total(switch_off))

    # Investment (only if any candidates exist)
    if haskey(sol, "Thermal: Investment status")
        invest_status = sol["Thermal: Investment status"]
        invest_units = [g for g in thermal_units if g.invest > 0.0]
        if !isempty(invest_units)
            summary["Thermal: Total investment cost (\$)"] = sum(
                invest_status[g.name] * g.invest for g in invest_units
            )
            summary["Thermal: Units invested"] = count(
                g -> invest_status[g.name] > 0.5,
                invest_units,
            )
        end
    end
    return
end

function _store_thermal_solution!(
    sol::OrderedDict,
    model::JuMP.Model,
    sc,
    T::Int,
)
    thermal_production = OrderedDict(
        g.name => _thermal_production(model, g, sc, T) for g in sc[:thermal]
    )
    sol["Thermal: Production (MW)"] = thermal_production
    sol["Thermal: Utilization (%)"] = OrderedDict(
        g.name => [
            round(
                100.0 * thermal_production[g.name][t] / g.max_power[t],
                digits = 2,
            ) for t in 1:T
        ] for g in sc[:thermal]
    )
    sol["Thermal: Production cost (\$)"] = OrderedDict(
        g.name => _thermal_production_cost(model, g, sc, T) for
        g in sc[:thermal]
    )
    sol["Thermal: Startup cost (\$)"] = OrderedDict(
        g.name => _thermal_startup_cost(model, g, T) for g in sc[:thermal]
    )
    sol["Thermal: Shutdown cost (\$)"] = OrderedDict(
        g.name => _thermal_shutdown_cost(model, g, T) for g in sc[:thermal]
    )
    sol["Thermal: Is on"] = _timeseries(model, :is_on, sc[:thermal], T)
    sol["Thermal: Switch on"] = _timeseries(model, :switch_on, sc[:thermal], T)
    sol["Thermal: Switch off"] =
        _timeseries(model, :switch_off, sc[:thermal], T)
    sol["Thermal: Investment status"] = OrderedDict(
        g.name => value(model[:invest][g.name]) for
        g in sc[:thermal] if g.invest > 0.0
    )
    sol["Thermal: Reactive power (MVAr)"] =
        _timeseries(model, :qg_thermal, sc[:thermal], T, sc = sc)
    return
end

function _thermal_production(model::JuMP.Model, g, sc, T::Int)
    return [
        value(model[:is_on][g.name, t]) * g.min_power[t] + sum(
            Float64[
                value(model[:segprod][sc.name, g.name, t, k]) for
                k in 1:length(g.cost_segments)
            ],
        ) for t in 1:T
    ]
end

function _thermal_production_cost(model::JuMP.Model, g, sc, T::Int)
    return [
        value(model[:is_on][g.name, t]) * g.min_power_cost[t] + sum(
            Float64[
                value(model[:segprod][sc.name, g.name, t, k]) *
                g.cost_segments[k].cost[t] for k in 1:length(g.cost_segments)
            ],
        ) for t in 1:T
    ]
end

function _thermal_startup_cost(model::JuMP.Model, g, T::Int)
    S = length(g.startup_categories)
    return [
        sum(
            g.startup_categories[s].cost * value(model[:startup][g.name, t, s])
            for s in 1:S
        ) for t in 1:T
    ]
end

function _thermal_shutdown_cost(model::JuMP.Model, g, T::Int)
    return [g.shutdown_cost * value(model[:switch_off][g.name, t]) for t in 1:T]
end

function _store_reserve_solution!(
    sol::OrderedDict,
    model::JuMP.Model,
    sc,
    T::Int,
)
    sol["Reserve: Provided (MW)"] = OrderedDict(
        r.name => OrderedDict(
            g.name => [
                value(model[:reserve][sc.name, r.name, g.name, t]) for t in 1:T
            ] for g in r.thermal_units
        ) for r in sc[:reserves]
    )
    sol["Reserve: Shortfall (MW)"] = OrderedDict(
        r.name => [
            value(model[:reserve_shortfall][sc.name, r.name, t]) for t in 1:T
        ] for r in sc[:reserves]
    )
    return
end
