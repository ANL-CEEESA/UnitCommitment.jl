# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

function store_solution(
    sol::AbstractDict,
    model::JuMP.Model,
    ::ThermalExt,
)::Nothing
    instance = model[:instance]
    T = instance.time
    for sc in instance.scenarios
        _store_thermal_solution!(sol[sc.name], model, sc, T)
        _store_reserve_solution!(sol[sc.name], model, sc, T)
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
        g.name => _thermal_production(model, g, sc, T) for
        g in sc.data[:thermal]
    )
    sol["Thermal: Production (MW)"] = thermal_production
    sol["Thermal: Utilization (%)"] = OrderedDict(
        g.name => [
            round(
                100.0 * thermal_production[g.name][t] / g.max_power[t],
                digits = 2,
            ) for t in 1:T
        ] for g in sc.data[:thermal]
    )
    sol["Thermal: Production cost (\$)"] = OrderedDict(
        g.name => _thermal_production_cost(model, g, sc, T) for
        g in sc.data[:thermal]
    )
    sol["Thermal: Startup cost (\$)"] = OrderedDict(
        g.name => _thermal_startup_cost(model, g, T) for g in sc.data[:thermal]
    )
    sol["Thermal: Is on"] = _timeseries(model, :is_on, sc.data[:thermal], T)
    sol["Thermal: Switch on"] =
        _timeseries(model, :switch_on, sc.data[:thermal], T)
    sol["Thermal: Switch off"] =
        _timeseries(model, :switch_off, sc.data[:thermal], T)
    sol["Thermal: Investment status"] = OrderedDict(
        g.name => [value(model[:invest][g.name, t]) for t in 1:T] for
        g in sc.data[:thermal] if g.invest[1] > 0.0
    )
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

function _store_reserve_solution!(
    sol::OrderedDict,
    model::JuMP.Model,
    sc,
    T::Int,
)
    sol["Reserve: Spinning (MW)"] = OrderedDict(
        r.name => OrderedDict(
            g.name => [
                value(model[:reserve][sc.name, r.name, g.name, t]) for t in 1:T
            ] for g in r.thermal_units
        ) for r in sc.data[:reserves]
    )
    sol["Reserve: Spinning shortfall (MW)"] = OrderedDict(
        r.name => [
            value(model[:reserve_shortfall][sc.name, r.name, t]) for t in 1:T
        ] for r in sc.data[:reserves]
    )
    return
end
