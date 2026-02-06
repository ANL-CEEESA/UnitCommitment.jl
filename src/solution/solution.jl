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

function _store_solution!(model::JuMP.Model)::Nothing
    instance, T = model[:instance], model[:instance].time
    function timeseries(sym::Symbol, collection; sc = nothing)
        isempty(collection) && return OrderedDict{String,Vector{Float64}}()
        vars = model[sym]
        if sc === nothing
            return OrderedDict(
                b.name =>
                    [round(value(vars[b.name, t]), digits = 5) for t in 1:T] for
                b in collection
            )
        else
            return OrderedDict(
                b.name => [
                    round(value(vars[sc.name, b.name, t]), digits = 5) for
                    t in 1:T
                ] for b in collection
            )
        end
    end
    function production_cost(g, sc)
        return [
            value(model[:is_on][g.name, t]) * g.min_power_cost[t] + sum(
                Float64[
                    value(model[:segprod][sc.name, g.name, t, k]) *
                    g.cost_segments[k].cost[t] for
                    k in 1:length(g.cost_segments)
                ],
            ) for t in 1:T
        ]
    end
    function production(g, sc)
        return [
            value(model[:is_on][g.name, t]) * g.min_power[t] + sum(
                Float64[
                    value(model[:segprod][sc.name, g.name, t, k]) for
                    k in 1:length(g.cost_segments)
                ],
            ) for t in 1:T
        ]
    end
    function startup_cost(g, sc)
        S = length(g.startup_categories)
        return [
            sum(
                g.startup_categories[s].cost *
                value(model[:startup][g.name, t, s]) for s in 1:S
            ) for t in 1:T
        ]
    end
    sol = OrderedDict()
    for sc in instance.scenarios
        sol[sc.name] = OrderedDict()
        sol[sc.name]["Bus: Net injection (MW)"] =
            timeseries(:net_injection, sc.buses, sc = sc)
        sol[sc.name]["Bus: Load curtail (MW)"] =
            timeseries(:curtail, sc.buses, sc = sc)
        sol[sc.name]["Thermal: Production (MW)"] = OrderedDict(
            g.name => production(g, sc) for g in sc.thermal_units
        )
        sol[sc.name]["Thermal: Production cost (\$)"] = OrderedDict(
            g.name => production_cost(g, sc) for g in sc.thermal_units
        )
        sol[sc.name]["Thermal: Startup cost (\$)"] = OrderedDict(
            g.name => startup_cost(g, sc) for g in sc.thermal_units
        )
        sol[sc.name]["Thermal: Is on"] = timeseries(:is_on, sc.thermal_units)
        sol[sc.name]["Thermal: Switch on"] =
            timeseries(:switch_on, sc.thermal_units)
        sol[sc.name]["Thermal: Switch off"] =
            timeseries(:switch_off, sc.thermal_units)
        sol[sc.name]["Thermal: Investment status"] = OrderedDict(
            g.name =>
                [value(model[:invest_unit][g.name, t]) for t in 1:T] for
            g in sc.thermal_units if g.invest[1] > 0.0
        )
        sol[sc.name]["Line: Overflow (MW)"] =
            timeseries(:overflow, sc.lines, sc = sc)
        sol[sc.name]["Line: Investment status"] = OrderedDict(
            lm.name =>
                [value(model[:invest_line][lm.name, t]) for t in 1:T]
            for lm in sc.lines if lm.invest[1] > 0.0
        )
        sol[sc.name]["Price-sensitive load: Demand served (MW)"] =
            timeseries(:loads, sc.price_sensitive_loads, sc = sc)
        sol[sc.name]["Profiled: Production (MW)"] =
            timeseries(:prod_profiled, sc.profiled_units, sc = sc)
        sol[sc.name]["Profiled: Production cost (\$)"] = OrderedDict(
            pu.name => [
                value(model[:prod_profiled][sc.name, pu.name, t]) *
                pu.cost[t] for t in 1:instance.time
            ] for pu in sc.profiled_units
        )
        sol[sc.name]["Profiled: Investment status"] = OrderedDict(
            pu.name =>
                [value(model[:invest_unit][pu.name, t]) for t in 1:T]
            for pu in sc.profiled_units if pu.invest[1] > 0.0
        )
        sol[sc.name]["Storage: Level (MWh)"] =
            timeseries(:storage_level, sc.storage_units, sc = sc)
        sol[sc.name]["Storage: Is charging"] =
            timeseries(:is_charging, sc.storage_units, sc = sc)
        sol[sc.name]["Storage: Charging rate (MW)"] =
            timeseries(:charge_rate, sc.storage_units, sc = sc)
        sol[sc.name]["Storage: Charging cost (\$)"] = OrderedDict(
            su.name => [
                value(model[:charge_rate][sc.name, su.name, t]) *
                su.charge_cost[t] for t in 1:instance.time
            ] for su in sc.storage_units
        )
        sol[sc.name]["Storage: Is discharging"] =
            timeseries(:is_discharging, sc.storage_units, sc = sc)
        sol[sc.name]["Storage: Discharging rate (MW)"] =
            timeseries(:discharge_rate, sc.storage_units, sc = sc)
        sol[sc.name]["Storage: Discharging cost (\$)"] = OrderedDict(
            su.name => [
                value(model[:discharge_rate][sc.name, su.name, t]) *
                su.discharge_cost[t] for t in 1:instance.time
            ] for su in sc.storage_units
        )
        sol[sc.name]["Storage: Investment status"] = OrderedDict(
            su.name => [
                value(model[:invest_storage][su.name, t]) for t in 1:T
            ] for su in sc.storage_units if su.invest[1] > 0.0
        )
        sol[sc.name]["Reserve: Spinning (MW)"] = OrderedDict(
            r.name => OrderedDict(
                g.name => [
                    value(model[:reserve][sc.name, r.name, g.name, t]) for t in 1:instance.time
                ] for g in r.thermal_units
            ) for r in sc.reserves if r.type == "spinning"
        )
        sol[sc.name]["Reserve: Spinning shortfall (MW)"] = OrderedDict(
            r.name => [
                value(model[:reserve_shortfall][sc.name, r.name, t]) for
                t in 1:instance.time
            ] for r in sc.reserves if r.type == "spinning"
        )
        sol[sc.name]["Reserve: Up-flexiramp (MW)"] = OrderedDict(
            r.name => OrderedDict(
                g.name => [
                    value(model[:upflexiramp][sc.name, r.name, g.name, t]) for t in 1:instance.time
                ] for g in r.thermal_units
            ) for r in sc.reserves if r.type == "flexiramp"
        )
        sol[sc.name]["Reserve: Up-flexiramp shortfall (MW)"] = OrderedDict(
            r.name => [
                value(model[:upflexiramp_shortfall][sc.name, r.name, t]) for t in 1:instance.time
            ] for r in sc.reserves if r.type == "flexiramp"
        )
        sol[sc.name]["Reserve: Down-flexiramp (MW)"] = OrderedDict(
            r.name => OrderedDict(
                g.name => [
                    value(model[:dwflexiramp][sc.name, r.name, g.name, t]) for t in 1:instance.time
                ] for g in r.thermal_units
            ) for r in sc.reserves if r.type == "flexiramp"
        )
        sol[sc.name]["Reserve: Down-flexiramp shortfall (MW)"] = OrderedDict(
            r.name => [
                value(model[:dwflexiramp_shortfall][sc.name, r.name, t]) for t in 1:instance.time
            ] for r in sc.reserves if r.type == "flexiramp"
        )
    end
    model.ext[:ucjl][:solution] = sol
    return
end
