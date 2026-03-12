# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using JuMP
using Printf

function read_json(
    json::AbstractDict,
    sc::UnitCommitmentScenario,
    ::VirtualTransactionsExt,
)
    T = sc[:time]
    virtuals = VirtualTransaction[]

    if "Virtual transactions" in keys(json)
        for (vt_name, dict) in json["Virtual transactions"]
            type_str = dict["Type"]
            type_sym = Symbol(lowercase(type_str))

            # Determine source/sink buses
            if type_sym == :utc
                bus_source = sc[:bus_by_name][dict["Source bus"]]
                bus_sink = sc[:bus_by_name][dict["Sink bus"]]
            else
                bus = sc[:bus_by_name][dict["Bus"]]
                bus_source = bus
                bus_sink = bus
            end

            # Validate type
            type_sym in (:inc, :dec, :utc) || error(
                "Unknown virtual transaction type $type_str for " *
                "virtual transaction $vt_name. " *
                "Expected INC, DEC, or UTC.",
            )

            # Determine price field
            price_raw = if type_sym == :inc
                dict["Offer price (\$/MW)"]
            else
                dict["Bid price (\$/MW)"]
            end

            vt = VirtualTransaction(
                name = vt_name,
                type = type_sym,
                bus_source = bus_source,
                bus_sink = bus_sink,
                price = to_timeseries(price_raw, T),
                max_quantity = to_timeseries(dict["Maximum quantity (MW)"], T),
            )
            push!(virtuals, vt)
        end
    end

    sc[:virtual] = virtuals
    sc[:virtual_by_name] = Dict(vt.name => vt for vt in virtuals)
    return
end

function build_model(
    model::JuMP.Model,
    instance::UnitCommitmentInstance,
    ::VirtualTransactionsExt,
)::Nothing
    T = instance.time
    vt_cleared = _init(model, :vt_cleared)

    for sc in instance.scenarios, vt in sc[:virtual], t in 1:T
        # Continuous variable: 0 <= cleared <= max_quantity
        vt_cleared[sc.name, vt.name, t] =
            @variable(model, lower_bound = 0, upper_bound = vt.max_quantity[t],)

        if vt.type == :inc
            # Virtual supply: injects power at source bus
            add_to_expression!(
                model[:net_injection][sc.name, vt.bus_source.name, t],
                vt_cleared[sc.name, vt.name, t],
                1.0,
            )
            # Offer cost (positive: supply offers energy)
            add_to_expression!(
                model[:obj],
                vt_cleared[sc.name, vt.name, t],
                vt.price[t] * sc[:probability],
            )
        elseif vt.type == :dec
            # Virtual demand: withdraws power at sink bus
            add_to_expression!(
                model[:net_injection][sc.name, vt.bus_sink.name, t],
                vt_cleared[sc.name, vt.name, t],
                -1.0,
            )
            # Bid benefit (negative cost: demand pays for energy)
            add_to_expression!(
                model[:obj],
                vt_cleared[sc.name, vt.name, t],
                -vt.price[t] * sc[:probability],
            )
        elseif vt.type == :utc
            # Source injection
            add_to_expression!(
                model[:net_injection][sc.name, vt.bus_source.name, t],
                vt_cleared[sc.name, vt.name, t],
                1.0,
            )
            # Sink withdrawal
            add_to_expression!(
                model[:net_injection][sc.name, vt.bus_sink.name, t],
                vt_cleared[sc.name, vt.name, t],
                -1.0,
            )
            # Spread bid (negative cost: willing to pay for congestion)
            add_to_expression!(
                model[:obj],
                vt_cleared[sc.name, vt.name, t],
                -vt.price[t] * sc[:probability],
            )
        end
    end
    return
end

function store_solution(
    sol::AbstractDict,
    model::UnitCommitmentModel,
    ::VirtualTransactionsExt,
)::Nothing
    instance = model.instance
    inner = model.inner
    T = instance.time
    for sc in instance.scenarios
        sol[sc.name]["Virtual: Cleared (MW)"] =
            _timeseries(inner, :vt_cleared, sc[:virtual], T, sc = sc)

        _store_virtual_summary!(sol[sc.name], sc, T)
    end
    return
end

function _store_virtual_summary!(sol::OrderedDict, sc, T::Int)
    summary = sol["Summary"]

    cleared = sol["Virtual: Cleared (MW)"]
    virtuals = sc[:virtual]

    inc_total = sum(
        sum(cleared[vt.name]) for vt in virtuals if vt.type == :inc;
        init = 0.0,
    )
    dec_total = sum(
        sum(cleared[vt.name]) for vt in virtuals if vt.type == :dec;
        init = 0.0,
    )
    utc_total = sum(
        sum(cleared[vt.name]) for vt in virtuals if vt.type == :utc;
        init = 0.0,
    )

    summary["Virtual: Total INC cleared (MW)"] = inc_total
    summary["Virtual: Total DEC cleared (MW)"] = dec_total
    summary["Virtual: Total UTC cleared (MW)"] = utc_total

    # Net objective cost
    summary["Virtual: Net objective cost (\$)"] = sum(
        begin
            sign = vt.type == :inc ? 1.0 : -1.0
            sum(sign * vt.price[t] * cleared[vt.name][t] for t in 1:T)
        end for vt in virtuals;
        init = 0.0,
    )
    return
end

function validate(
    instance::UnitCommitmentInstance,
    solution::AbstractDict,
    ::VirtualTransactionsExt;
    tol = 0.01,
)::Int
    err_count = 0
    for sc in instance.scenarios, vt in sc[:virtual], t in 1:instance.time
        cleared = solution[sc.name]["Virtual: Cleared (MW)"][vt.name][t]

        if cleared < -tol
            @error @sprintf(
                "Virtual transaction %s has negative cleared quantity at time %d (%.2f < 0)",
                vt.name,
                t,
                cleared,
            )
            err_count += 1
        end

        if cleared > vt.max_quantity[t] + tol
            @error @sprintf(
                "Virtual transaction %s exceeds maximum quantity at time %d (%.2f > %.2f)",
                vt.name,
                t,
                cleared,
                vt.max_quantity[t],
            )
            err_count += 1
        end
    end
    return err_count
end

function summarize(
    instance::UnitCommitmentInstance,
    ::VirtualTransactionsExt,
    io::IO,
)::Nothing
    count = length(instance.scenarios[1][:virtual])
    count > 0 && print(io, "$count virtual transactions, ")
    return
end

function slice!(
    sc::UnitCommitmentScenario,
    range::UnitRange{Int},
    ::VirtualTransactionsExt,
)::Nothing
    for vt in sc[:virtual]
        vt.price = vt.price[range]
        vt.max_quantity = vt.max_quantity[range]
    end
    return
end
