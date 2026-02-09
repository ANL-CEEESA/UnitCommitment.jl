# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using JuMP
using Printf

function _read!(
    json::AbstractDict,
    sc::UnitCommitmentScenario,
    ::PriceSensitiveLoads,
)
    T = sc.time
    loads = PriceSensitiveLoad[]

    if "Price-sensitive loads" in keys(json)
        for (load_name, dict) in json["Price-sensitive loads"]
            bus = sc.buses_by_name[dict["Bus"]]
            load = PriceSensitiveLoad(
                load_name,
                bus,
                to_timeseries(dict["Demand (MW)"], T),
                to_timeseries(dict["Revenue (\$/MW)"], T),
            )
            push!(loads, load)
        end
    end

    sc.data[:psload] = loads
    sc.data[:psload_by_name] = Dict(ps.name => ps for ps in loads)
    return
end

function _build!(
    model::JuMP.Model,
    instance::UnitCommitmentInstance,
    ::PriceSensitiveLoads,
)::Nothing
    T = instance.time
    loads = _init(model, :loads)

    for sc in instance.scenarios
        ps_loads = sc.data[:psload]
        for ps in ps_loads, t in 1:T
            loads[sc.name, ps.name, t] =
                @variable(model, lower_bound = 0, upper_bound = ps.demand[t])
            add_to_expression!(
                model[:net_injection][sc.name, ps.bus.name, t],
                loads[sc.name, ps.name, t],
                -1.0,
            )
        end
    end

    for t in 1:T, sc in instance.scenarios
        ps_loads = sc.data[:psload]
        for ps in ps_loads
            add_to_expression!(
                model[:obj],
                loads[sc.name, ps.name, t],
                -ps.revenue[t] * sc.probability,
            )
        end
    end

    return
end

function _solution!(
    sol::AbstractDict,
    model::JuMP.Model,
    ::PriceSensitiveLoads,
)::Nothing
    instance = model[:instance]
    T = instance.time
    for sc in instance.scenarios
        ps_loads = sc.data[:psload]
        sol[sc.name]["Price-sensitive load: Demand served (MW)"] =
            _timeseries(model, :loads, ps_loads, T, sc = sc)
    end
    return
end

function _validate!(
    instance::UnitCommitmentInstance,
    solution::AbstractDict,
    ::PriceSensitiveLoads;
    tol = 0.01,
)::Int
    err_count = 0
    for t in 1:instance.time, sc in instance.scenarios
        for ps in sc.data[:psload]
            demand_served = solution[sc.name]["Price-sensitive load: Demand served (MW)"][ps.name][t]

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
    end

    return err_count
end

function _summarize(
    instance::UnitCommitmentInstance,
    ::PriceSensitiveLoads,
    io::IO,
)::Nothing
    sc = instance.scenarios[1]
    count = length(sc.data[:psload])
    print(io, "$count price sensitive loads, ")
    return
end

function _slice!(
    sc::UnitCommitmentScenario,
    range::UnitRange{Int},
    ::PriceSensitiveLoads,
)::Nothing
    ps_loads = sc.data[:psload]
    for ps in ps_loads
        ps.demand = ps.demand[range]
        ps.revenue = ps.revenue[range]
    end
    return
end
