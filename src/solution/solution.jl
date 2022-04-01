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
    if instance.reserves.upflexiramp != zeros(T) ||
       instance.reserves.dwflexiramp != zeros(T)
        # Report flexiramp solutions only if either of the up-flexiramp and  
        # down-flexiramp requirements is not a default array of zeros
        sol["Up-flexiramp (MW)"] =
            timeseries(model[:upflexiramp], instance.units)
        sol["Up-flexiramp shortfall (MW)"] = OrderedDict(
            t =>
                (instance.flexiramp_shortfall_penalty[t] >= 0) ?
                round(value(model[:upflexiramp_shortfall][t]), digits = 5) :
                0.0 for t in 1:instance.time
        )
        sol["Down-flexiramp (MW)"] =
            timeseries(model[:dwflexiramp], instance.units)
        sol["Down-flexiramp shortfall (MW)"] = OrderedDict(
            t =>
                (instance.flexiramp_shortfall_penalty[t] >= 0) ?
                round(value(model[:dwflexiramp_shortfall][t]), digits = 5) :
                0.0 for t in 1:instance.time
        )
    else
        # Report spinning reserve solutions only if both up-flexiramp and  
        # down-flexiramp requirements are arrays of zeros.
        sol["Reserve (MW)"] = timeseries(model[:reserve], instance.units)
        sol["Reserve shortfall (MW)"] = OrderedDict(
            t =>
                (instance.shortfall_penalty[t] >= 0) ?
                round(value(model[:reserve_shortfall][t]), digits = 5) :
                0.0 for t in 1:instance.time
        )
    end
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
    return sol
end
