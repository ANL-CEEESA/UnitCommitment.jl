# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

function read_json(json::AbstractDict, sc::UnitCommitmentScenario, ::StorageExt)
    T = sc.time
    storage_units = StorageUnit[]

    if "Storage units" in keys(json)
        for (storage_name, dict) in json["Storage units"]
            bus = sc.data[:bus_by_name][dict["Bus"]]
            min_level = to_timeseries(
                to_scalar(dict["Minimum level (MWh)"], default = 0.0),
                T,
            )
            max_level = to_timeseries(dict["Maximum level (MWh)"], T)
            storage = StorageUnit(
                name = storage_name,
                bus = bus,
                min_level = min_level,
                max_level = max_level,
                simultaneous_charge_and_discharge = to_timeseries(
                    to_scalar(
                        dict["Allow simultaneous charging and discharging"],
                        default = true,
                    ),
                    T,
                ),
                charge_cost = to_timeseries(dict["Charge cost (\$/MW)"], T),
                discharge_cost = to_timeseries(
                    dict["Discharge cost (\$/MW)"],
                    T,
                ),
                charge_efficiency = to_timeseries(
                    to_scalar(dict["Charge efficiency"], default = 1.0),
                    T,
                ),
                discharge_efficiency = to_timeseries(
                    to_scalar(dict["Discharge efficiency"], default = 1.0),
                    T,
                ),
                loss_factor = to_timeseries(
                    to_scalar(dict["Loss factor"], default = 0.0),
                    T,
                ),
                min_charge_rate = to_timeseries(
                    to_scalar(dict["Minimum charge rate (MW)"], default = 0.0),
                    T,
                ),
                max_charge_rate = to_timeseries(
                    dict["Maximum charge rate (MW)"],
                    T,
                ),
                min_discharge_rate = to_timeseries(
                    to_scalar(
                        dict["Minimum discharge rate (MW)"],
                        default = 0.0,
                    ),
                    T,
                ),
                max_discharge_rate = to_timeseries(
                    dict["Maximum discharge rate (MW)"],
                    T,
                ),
                initial_level = to_scalar(
                    dict["Initial level (MWh)"],
                    default = 0.0,
                ),
                min_ending_level = to_scalar(
                    dict["Last period minimum level (MWh)"],
                    default = min_level[T],
                ),
                max_ending_level = to_scalar(
                    dict["Last period maximum level (MWh)"],
                    default = max_level[T],
                ),
                invest = to_timeseries(
                    to_scalar(dict["Investment cost (\$)"], default = 0.0),
                    T,
                ),
            )
            push!(storage_units, storage)
        end
    end

    sc.data[:storage] = storage_units
    sc.data[:storage_by_name] = Dict(su.name => su for su in storage_units)
    return
end
