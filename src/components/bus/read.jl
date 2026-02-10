# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

function _read_buses!(json::AbstractDict, sc::UnitCommitmentScenario)::Nothing
    T = sc[:time]
    buses = Bus[]
    name_to_bus = Dict{String,Bus}()

    # Read buses
    for (bus_name, dict) in json["Buses"]
        bus = Bus(bus_name, length(buses), to_timeseries(dict["Load (MW)"], T))
        name_to_bus[bus_name] = bus
        push!(buses, bus)
    end

    sc[:bus] = buses
    sc[:bus_by_name] = name_to_bus
    return
end
