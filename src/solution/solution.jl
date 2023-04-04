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
    instance, T = model[:instance], model[:instance].time
    function timeseries(vars, collection; sc = nothing)
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
        if !isempty(sc.thermal_units)
            sol[sc.name]["Production (MW)"] = OrderedDict(
                g.name => production(g, sc) for g in sc.thermal_units
            )
            sol[sc.name]["Production cost (\$)"] = OrderedDict(
                g.name => production_cost(g, sc) for g in sc.thermal_units
            )
            sol[sc.name]["Startup cost (\$)"] = OrderedDict(
                g.name => startup_cost(g, sc) for g in sc.thermal_units
            )
            sol[sc.name]["Is on"] = timeseries(model[:is_on], sc.thermal_units)
            sol[sc.name]["Switch on"] =
                timeseries(model[:switch_on], sc.thermal_units)
            sol[sc.name]["Switch off"] =
                timeseries(model[:switch_off], sc.thermal_units)
            sol[sc.name]["Net injection (MW)"] =
                timeseries(model[:net_injection], sc.buses, sc = sc)
            sol[sc.name]["Load curtail (MW)"] =
                timeseries(model[:curtail], sc.buses, sc = sc)
        end
        if !isempty(sc.lines)
            sol[sc.name]["Line overflow (MW)"] =
                timeseries(model[:overflow], sc.lines, sc = sc)
        end
        if !isempty(sc.price_sensitive_loads)
            sol[sc.name]["Price-sensitive loads (MW)"] =
                timeseries(model[:loads], sc.price_sensitive_loads, sc = sc)
        end
        if !isempty(sc.profiled_units)
            sol[sc.name]["Profiled production (MW)"] =
                timeseries(model[:prod_profiled], sc.profiled_units, sc = sc)
            sol[sc.name]["Profiled production cost (\$)"] = OrderedDict(
                pu.name => [
                    value(model[:prod_profiled][sc.name, pu.name, t]) *
                    pu.cost[t] for t in 1:instance.time
                ] for pu in sc.profiled_units
            )
        end
        sol[sc.name]["Spinning reserve (MW)"] = OrderedDict(
            r.name => OrderedDict(
                g.name => [
                    value(model[:reserve][sc.name, r.name, g.name, t]) for t in 1:instance.time
                ] for g in r.thermal_units
            ) for r in sc.reserves if r.type == "spinning"
        )
        sol[sc.name]["Spinning reserve shortfall (MW)"] = OrderedDict(
            r.name => [
                value(model[:reserve_shortfall][sc.name, r.name, t]) for
                t in 1:instance.time
            ] for r in sc.reserves if r.type == "spinning"
        )
        sol[sc.name]["Up-flexiramp (MW)"] = OrderedDict(
            r.name => OrderedDict(
                g.name => [
                    value(model[:upflexiramp][sc.name, r.name, g.name, t]) for t in 1:instance.time
                ] for g in r.thermal_units
            ) for r in sc.reserves if r.type == "flexiramp"
        )
        sol[sc.name]["Up-flexiramp shortfall (MW)"] = OrderedDict(
            r.name => [
                value(model[:upflexiramp_shortfall][sc.name, r.name, t]) for t in 1:instance.time
            ] for r in sc.reserves if r.type == "flexiramp"
        )
        sol[sc.name]["Down-flexiramp (MW)"] = OrderedDict(
            r.name => OrderedDict(
                g.name => [
                    value(model[:dwflexiramp][sc.name, r.name, g.name, t]) for t in 1:instance.time
                ] for g in r.thermal_units
            ) for r in sc.reserves if r.type == "flexiramp"
        )
        sol[sc.name]["Down-flexiramp shortfall (MW)"] = OrderedDict(
            r.name => [
                value(model[:dwflexiramp_shortfall][sc.name, r.name, t]) for t in 1:instance.time
            ] for r in sc.reserves if r.type == "flexiramp"
        )
    end
    if length(instance.scenarios) == 1
        return first(values(sol))
    else
        return sol
    end
end
