# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using JuMP
using Printf

function read_json(
    json::AbstractDict,
    sc::UnitCommitmentScenario,
    ::PriceSensitiveLoadsExt,
)
    T = sc[:time]
    loads = PriceSensitiveLoad[]

    if "Price-sensitive loads" in keys(json)
        for (load_name, dict) in json["Price-sensitive loads"]
            bus = sc[:bus_by_name][dict["Bus"]]
            load = PriceSensitiveLoad(
                name = load_name,
                bus = bus,
                demand = to_timeseries(dict["Demand (MW)"], T),
                revenue = to_timeseries(dict["Revenue (\$/MW)"], T),
            )
            push!(loads, load)
        end
    end

    sc[:psload] = loads
    sc[:psload_by_name] = Dict(ps.name => ps for ps in loads)
    return
end

function build_model(
    model::JuMP.Model,
    instance::UnitCommitmentInstance,
    ::PriceSensitiveLoadsExt,
)::Nothing
    T = instance.time
    loads = _init(model, :loads)
    for sc in instance.scenarios, ps in sc[:psload], t in 1:T
        loads[sc.name, ps.name, t] =
            @variable(model, lower_bound = 0, upper_bound = ps.demand[t])
        add_to_expression!(
            model[:net_injection][sc.name, ps.bus.name, t],
            loads[sc.name, ps.name, t],
            -1.0,
        )
        add_to_expression!(
            model[:obj],
            loads[sc.name, ps.name, t],
            -ps.revenue[t] * sc[:probability],
        )
    end
    return
end

function store_solution(
    sol::AbstractDict,
    model::UnitCommitmentModel,
    ::PriceSensitiveLoadsExt,
)::Nothing
    instance = model.instance
    inner = model.inner
    T = instance.time
    for sc in instance.scenarios
        demand = _timeseries(inner, :loads, sc[:psload], T, sc = sc)
        sol[sc.name]["Price-sensitive load: Demand served (MW)"] = demand
        sol[sc.name]["Summary"]["Price-sensitive load: Total demand served (MW)"] =
            _total(demand)
    end
    return
end

function validate(
    instance::UnitCommitmentInstance,
    solution::AbstractDict,
    ::PriceSensitiveLoadsExt;
    tol = 0.01,
)::Int
    err_count = 0
    for sc in instance.scenarios, ps in sc[:psload], t in 1:instance.time
        demand_served =
            solution[sc.name]["Price-sensitive load: Demand served (MW)"][ps.name][t]

        # Demand served must be non-negative
        if demand_served < -tol
            @error @sprintf(
                "Price-sensitive load %s has negative demand served at time %d (%.2f < 0)",
                ps.name,
                t,
                demand_served
            )
            err_count += 1
        end

        # Demand served must not exceed maximum demand
        if demand_served > ps.demand[t] + tol
            @error @sprintf(
                "Price-sensitive load %s exceeds maximum demand at time %d (%.2f > %.2f)",
                ps.name,
                t,
                demand_served,
                ps.demand[t]
            )
            err_count += 1
        end
    end

    return err_count
end

function summarize(
    instance::UnitCommitmentInstance,
    ::PriceSensitiveLoadsExt,
    io::IO,
)::Nothing
    count = length(instance.scenarios[1][:psload])
    print(io, "$count price sensitive loads, ")
    return
end

function slice!(
    sc::UnitCommitmentScenario,
    range::UnitRange{Int},
    ::PriceSensitiveLoadsExt,
)::Nothing
    for ps in sc[:psload]
        ps.demand = ps.demand[range]
        ps.revenue = ps.revenue[range]
    end
    return
end
