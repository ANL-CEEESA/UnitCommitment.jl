# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

"""
	solution(model::JuMP.Model)::OrderedDict

Extracts the optimal solution from the UC.jl model. The model must be solved beforehand.

# Example

```julia
UnitCommitment.optimize!(model)
solution = UnitCommitment.solution(model)
```
"""
function solution(model::JuMP.Model)::OrderedDict
    instance = model[:instance]
    sol = model.ext[:ucjl][:solution]

    for ext in instance.extensions
        _solution!(sol, model, ext)
    end

    if length(instance.scenarios) == 1
        sol = first(values(sol))
    end

    return sol
end

function _timeseries(
    model::JuMP.Model,
    sym::Symbol,
    collection,
    T::Int;
    sc = nothing,
)
    isempty(collection) && return OrderedDict{String,Vector{Float64}}()
    vars = model[sym]
    if sc === nothing
        return OrderedDict(
            b.name => [round(value(vars[b.name, t]), digits = 5) for t in 1:T]
            for b in collection
        )
    else
        return OrderedDict(
            b.name => [
                round(value(vars[sc.name, b.name, t]), digits = 5) for t in 1:T
            ] for b in collection
        )
    end
end

function _store_bus_solution!(sol::OrderedDict, model::JuMP.Model, sc, T::Int)
    sol["Bus: Net injection (MW)"] =
        _timeseries(model, :net_injection, sc.buses, T, sc = sc)
    sol["Bus: Load curtail (MW)"] =
        _timeseries(model, :curtail, sc.buses, T, sc = sc)
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

function _store_thermal_solution!(
    sol::OrderedDict,
    model::JuMP.Model,
    sc,
    T::Int,
)
    thermal_production = OrderedDict(
        g.name => _thermal_production(model, g, sc, T) for
        g in sc.thermal_units
    )
    sol["Thermal: Production (MW)"] = thermal_production
    sol["Thermal: Utilization (%)"] = OrderedDict(
        g.name => [
            round(
                100.0 * thermal_production[g.name][t] / g.max_power[t],
                digits = 2,
            ) for t in 1:T
        ] for g in sc.thermal_units
    )
    sol["Thermal: Production cost (\$)"] = OrderedDict(
        g.name => _thermal_production_cost(model, g, sc, T) for
        g in sc.thermal_units
    )
    sol["Thermal: Startup cost (\$)"] = OrderedDict(
        g.name => _thermal_startup_cost(model, g, T) for g in sc.thermal_units
    )
    sol["Thermal: Is on"] = _timeseries(model, :is_on, sc.thermal_units, T)
    sol["Thermal: Switch on"] =
        _timeseries(model, :switch_on, sc.thermal_units, T)
    sol["Thermal: Switch off"] =
        _timeseries(model, :switch_off, sc.thermal_units, T)
    sol["Thermal: Investment status"] = OrderedDict(
        g.name => [value(model[:invest_unit][g.name, t]) for t in 1:T] for
        g in sc.thermal_units if g.invest[1] > 0.0
    )
    return
end

function _store_line_solution!(sol::OrderedDict, model::JuMP.Model, sc, T::Int)
    non_slack_buses = [b for b in sc.buses if b.offset > 0]
    net_injection = model[:net_injection]
    net_injection_values = [
        value(net_injection[sc.name, b.name, t]) for b in non_slack_buses,
        t in 1:T
    ]
    flows = sc.isf * net_injection_values

    sol["Line: Flow (MW)"] = OrderedDict(
        line.name =>
            [round(flows[line.offset, t], digits = 5) for t in 1:T] for
        line in sc.lines
    )
    sol["Line: Overflow (MW)"] =
        _timeseries(model, :overflow, sc.lines, T, sc = sc)
    sol["Line: Overflow penalty (\$)"] = OrderedDict(
        line.name => [
            value(model[:overflow][sc.name, line.name, t]) *
            line.flow_limit_penalty[t] for t in 1:T
        ] for line in sc.lines
    )
    sol["Line: Utilization (%)"] = OrderedDict(
        line.name => [
            round(
                100.0 * abs(flows[line.offset, t]) / line.normal_flow_limit[t],
                digits = 2,
            ) for t in 1:T
        ] for line in sc.lines
    )
    sol["Line: Investment cost (\$)"] = OrderedDict(
        line.name => [
            (
                value(model[:invest_line][line.name, t]) -
                value(model[:invest_line][line.name, t-1])
            ) * line.invest[t] for t in 1:T
        ] for line in sc.lines if line.invest[1] > 0.0
    )
    sol["Line: Investment status"] = OrderedDict(
        line.name =>
            [value(model[:invest_line][line.name, t]) for t in 1:T] for
        line in sc.lines if line.invest[1] > 0.0
    )
    return
end

function _store_price_sensitive_load_solution!(
    sol::OrderedDict,
    model::JuMP.Model,
    sc,
    T::Int,
)
    sol["Price-sensitive load: Demand served (MW)"] =
        _timeseries(model, :loads, sc.price_sensitive_loads, T, sc = sc)
    return
end

function _store_profiled_solution!(
    sol::OrderedDict,
    model::JuMP.Model,
    sc,
    T::Int,
)
    sol["Profiled: Production (MW)"] =
        _timeseries(model, :prod_profiled, sc.profiled_units, T, sc = sc)
    sol["Profiled: Utilization (%)"] = OrderedDict(
        pu.name => [
            round(
                100.0 * value(model[:prod_profiled][sc.name, pu.name, t]) /
                pu.max_power[t],
                digits = 2,
            ) for t in 1:T
        ] for pu in sc.profiled_units
    )
    sol["Profiled: Production cost (\$)"] = OrderedDict(
        pu.name => [
            value(model[:prod_profiled][sc.name, pu.name, t]) * pu.cost[t] for t in 1:T
        ] for pu in sc.profiled_units
    )
    sol["Profiled: Investment status"] = OrderedDict(
        pu.name => [value(model[:invest_unit][pu.name, t]) for t in 1:T] for
        pu in sc.profiled_units if pu.invest[1] > 0.0
    )
    return
end

function _store_storage_solution!(
    sol::OrderedDict,
    model::JuMP.Model,
    sc,
    T::Int,
)
    sol["Storage: Level (MWh)"] =
        _timeseries(model, :storage_level, sc.storage_units, T, sc = sc)
    sol["Storage: Is charging"] =
        _timeseries(model, :is_charging, sc.storage_units, T, sc = sc)
    sol["Storage: Charging rate (MW)"] =
        _timeseries(model, :charge_rate, sc.storage_units, T, sc = sc)
    sol["Storage: Charging cost (\$)"] = OrderedDict(
        su.name => [
            value(model[:charge_rate][sc.name, su.name, t]) * su.charge_cost[t] for t in 1:T
        ] for su in sc.storage_units
    )
    sol["Storage: Is discharging"] =
        _timeseries(model, :is_discharging, sc.storage_units, T, sc = sc)
    sol["Storage: Discharging rate (MW)"] =
        _timeseries(model, :discharge_rate, sc.storage_units, T, sc = sc)
    sol["Storage: Discharging cost (\$)"] = OrderedDict(
        su.name => [
            value(model[:discharge_rate][sc.name, su.name, t]) *
            su.discharge_cost[t] for t in 1:T
        ] for su in sc.storage_units
    )
    sol["Storage: Investment status"] = OrderedDict(
        su.name => [value(model[:invest_storage][su.name, t]) for t in 1:T]
        for su in sc.storage_units if su.invest[1] > 0.0
    )
    return
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
        ) for r in sc.reserves if r.type == "spinning"
    )
    sol["Reserve: Spinning shortfall (MW)"] = OrderedDict(
        r.name => [
            value(model[:reserve_shortfall][sc.name, r.name, t]) for t in 1:T
        ] for r in sc.reserves if r.type == "spinning"
    )
    sol["Reserve: Up-flexiramp (MW)"] = OrderedDict(
        r.name => OrderedDict(
            g.name => [
                value(model[:upflexiramp][sc.name, r.name, g.name, t]) for t in 1:T
            ] for g in r.thermal_units
        ) for r in sc.reserves if r.type == "flexiramp"
    )
    sol["Reserve: Up-flexiramp shortfall (MW)"] = OrderedDict(
        r.name => [
            value(model[:upflexiramp_shortfall][sc.name, r.name, t]) for
            t in 1:T
        ] for r in sc.reserves if r.type == "flexiramp"
    )
    sol["Reserve: Down-flexiramp (MW)"] = OrderedDict(
        r.name => OrderedDict(
            g.name => [
                value(model[:dwflexiramp][sc.name, r.name, g.name, t]) for t in 1:T
            ] for g in r.thermal_units
        ) for r in sc.reserves if r.type == "flexiramp"
    )
    sol["Reserve: Down-flexiramp shortfall (MW)"] = OrderedDict(
        r.name => [
            value(model[:dwflexiramp_shortfall][sc.name, r.name, t]) for
            t in 1:T
        ] for r in sc.reserves if r.type == "flexiramp"
    )
    return
end

function _store_solution!(model::JuMP.Model)::Nothing
    instance, T = model[:instance], model[:instance].time
    sol = OrderedDict()

    for sc in instance.scenarios
        sol[sc.name] = OrderedDict()
        _store_bus_solution!(sol[sc.name], model, sc, T)
        _store_thermal_solution!(sol[sc.name], model, sc, T)
        _store_line_solution!(sol[sc.name], model, sc, T)
        _store_price_sensitive_load_solution!(sol[sc.name], model, sc, T)
        _store_profiled_solution!(sol[sc.name], model, sc, T)
        _store_storage_solution!(sol[sc.name], model, sc, T)
        _store_reserve_solution!(sol[sc.name], model, sc, T)
    end

    model.ext[:ucjl][:solution] = sol
    return
end
