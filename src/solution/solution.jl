# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

function solution(model::JuMP.Model)::OrderedDict
    instance, T = model[:instance], model[:instance].time
    function timeseries(vars, collection)
        return OrderedDict(
            b.name => [round(value(vars[b.name, t]), digits = 5) for t in 1:T]
            for b in collection
        )
    end
    function production_cost(g)
        return [
            value(model[:is_on][g.name, t]) * g.min_power_cost[t] + sum(
                Float64[
                    value(model[:segprod][g.name, t, k]) *
                    g.cost_segments[k].cost[t] for
                    k in 1:length(g.cost_segments)
                ],
            ) for t in 1:T
        ]
    end
    function production(g)
        return [
            value(model[:is_on][g.name, t]) * g.min_power[t] + sum(
                Float64[
                    value(model[:segprod][g.name, t, k]) for
                    k in 1:length(g.cost_segments)
                ],
            ) for t in 1:T
        ]
    end
    function startup_cost(g)
        S = length(g.startup_categories)
        return [
            sum(
                g.startup_categories[s].cost *
                value(model[:startup][g.name, t, s]) for s in 1:S
            ) for t in 1:T
        ]
    end
    sol = OrderedDict()
    sol["Production (MW)"] =
        OrderedDict(g.name => production(g) for g in instance.units)
    sol["Production cost (\$)"] =
        OrderedDict(g.name => production_cost(g) for g in instance.units)
    sol["Startup cost (\$)"] =
        OrderedDict(g.name => startup_cost(g) for g in instance.units)
    sol["Is on"] = timeseries(model[:is_on], instance.units)
    sol["Switch on"] = timeseries(model[:switch_on], instance.units)
    sol["Switch off"] = timeseries(model[:switch_off], instance.units)
    sol["Net injection (MW)"] =
        timeseries(model[:net_injection], instance.buses)
    sol["Load curtail (MW)"] = timeseries(model[:curtail], instance.buses)
    if !isempty(instance.lines)
        sol["Line overflow (MW)"] = timeseries(model[:overflow], instance.lines)
    end
    if !isempty(instance.price_sensitive_loads)
        sol["Price-sensitive loads (MW)"] =
            timeseries(model[:loads], instance.price_sensitive_loads)
    end
    sol["Reserve (MW)"] = OrderedDict(
        r.name => OrderedDict(
            g.name => [
                value(model[:reserve][r.name, g.name, t]) for
                t in 1:instance.time
            ] for g in r.units
        ) for r in instance.reserves
    )
    sol["Reserve shortfall (MW)"] = OrderedDict(
        r.name => [
            value(model[:reserve_shortfall][r.name, t]) for
            t in 1:instance.time
        ] for r in instance.reserves
    )
    return sol
end
