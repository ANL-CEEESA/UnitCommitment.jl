# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

function read_json(json::AbstractDict, sc::UnitCommitmentScenario, ::ThermalExt)
    T = sc.time
    time_multiplier = 60 ÷ sc.time_step
    thermal_units = ThermalUnit[]
    reserves = SpinningReserve[]

    name_to_unit = Dict{String,ThermalUnit}()
    name_to_reserve = Dict{String,SpinningReserve}()

    # Read reserves (only spinning reserves are supported)
    if "Reserves" in keys(json)
        for (reserve_name, dict) in json["Reserves"]
            lowercase(dict["Type"]) == "spinning" || continue
            r = SpinningReserve(
                name = reserve_name,
                amount = to_timeseries(dict["Amount (MW)"], T),
                thermal_units = [],
                shortfall_penalty = to_scalar(
                    dict["Shortfall penalty (\$/MW)"],
                    default = -1,
                ),
            )
            name_to_reserve[reserve_name] = r
            push!(reserves, r)
        end
    end

    # Read units
    for (unit_name, dict) in json["Generators"]
        # Read and validate unit type
        unit_type = to_scalar(dict["Type"], default = nothing)
        unit_type !== nothing || error("unit $unit_name has no type specified")
        bus = sc.data[:bus_by_name][dict["Bus"]]

        if lowercase(unit_type) === "thermal"
            # Read production cost curve
            K = length(dict["Production cost curve (MW)"])
            curve_mw = hcat(
                [
                    to_timeseries(dict["Production cost curve (MW)"][k], T)
                    for k in 1:K
                ]...,
            )
            curve_cost = hcat(
                [
                    to_timeseries(dict["Production cost curve (\$)"][k], T)
                    for k in 1:K
                ]...,
            )
            min_power = curve_mw[:, 1]
            max_power = curve_mw[:, K]
            min_power_cost = curve_cost[:, 1]
            segments = CostSegment[]
            for k in 2:K
                amount = curve_mw[:, k] - curve_mw[:, k-1]
                cost = (curve_cost[:, k] - curve_cost[:, k-1]) ./ amount
                replace!(cost, NaN => 0.0)
                push!(segments, CostSegment(mw = amount, cost = cost))
            end

            # Read startup costs
            startup_delays =
                to_scalar(dict["Startup delays (h)"], default = [1])
            startup_costs =
                to_scalar(dict["Startup costs (\$)"], default = [0.0])
            startup_categories = StartupCategory[]
            for k in 1:length(startup_delays)
                push!(
                    startup_categories,
                    StartupCategory(
                        delay = startup_delays[k] .* time_multiplier,
                        cost = startup_costs[k],
                    ),
                )
            end

            # Read reserve eligibility
            unit_reserves = SpinningReserve[]
            if "Reserve eligibility" in keys(dict)
                unit_reserves = [
                    name_to_reserve[n] for
                    n in dict["Reserve eligibility"] if haskey(name_to_reserve, n)
                ]
            end

            # Read and validate initial conditions
            initial_power =
                to_scalar(dict["Initial power (MW)"], default = nothing)
            initial_status =
                to_scalar(dict["Initial status (h)"], default = nothing)
            if initial_power === nothing
                initial_status === nothing || error(
                    "unit $unit_name has initial status but no initial power",
                )
            else
                initial_status !== nothing || error(
                    "unit $unit_name has initial power but no initial status",
                )
                initial_status != 0 ||
                    error("unit $unit_name has invalid initial status")
                if initial_status < 0 && initial_power > 1e-3
                    error("unit $unit_name has invalid initial power")
                end
                initial_status *= time_multiplier
            end

            # Read commitment status
            commitment_status = to_scalar(
                dict["Commitment status"],
                default = Vector{Union{Bool,Nothing}}(nothing, T),
            )

            unit = ThermalUnit(
                name = unit_name,
                bus = bus,
                max_power = max_power,
                min_power = min_power,
                must_run = to_timeseries(
                    dict["Must run?"],
                    T,
                    default = [false for t in 1:T],
                ),
                min_power_cost = min_power_cost,
                cost_segments = segments,
                min_uptime = to_scalar(
                    dict["Minimum uptime (h)"],
                    default = 1,
                ) * time_multiplier,
                min_downtime = to_scalar(
                    dict["Minimum downtime (h)"],
                    default = 1,
                ) * time_multiplier,
                ramp_up_limit = to_scalar(
                    dict["Ramp up limit (MW)"],
                    default = 1e6,
                ),
                ramp_down_limit = to_scalar(
                    dict["Ramp down limit (MW)"],
                    default = 1e6,
                ),
                startup_limit = to_scalar(
                    dict["Startup limit (MW)"],
                    default = 1e6,
                ),
                shutdown_limit = to_scalar(
                    dict["Shutdown limit (MW)"],
                    default = 1e6,
                ),
                initial_status = initial_status,
                initial_power = initial_power,
                startup_categories = startup_categories,
                reserves = unit_reserves,
                commitment_status = commitment_status,
                invest = to_timeseries(
                    to_scalar(dict["Investment cost (\$)"], default = 0.0),
                    T,
                ),
            )
            for r in unit_reserves
                push!(r.thermal_units, unit)
            end
            name_to_unit[unit_name] = unit
            push!(thermal_units, unit)
        end
    end

    sc.data[:thermal] = thermal_units
    sc.data[:thermal_by_name] = Dict(g.name => g for g in thermal_units)
    sc.data[:reserves] = reserves
    sc.data[:reserves_by_name] = name_to_reserve
    return nothing
end
