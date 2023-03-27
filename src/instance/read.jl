# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using Printf
using JSON
using DataStructures
using GZip
import Base: getindex, time

const INSTANCES_URL = "https://axavier.org/UnitCommitment.jl/0.3/instances"

"""
    read_benchmark(name::AbstractString)::UnitCommitmentInstance

Read one of the benchmark instances included in the package. See
[Instances](instances.md) for the entire list of benchmark instances available.

# Example
```julia
instance = UnitCommitment.read_benchmark("matpower/case3375wp/2017-02-01")
```
"""
function read_benchmark(
    name::AbstractString;
    quiet::Bool = false,
)::UnitCommitmentInstance
    basedir = dirname(@__FILE__)
    filename = "$basedir/../../instances/$name.json.gz"
    url = "$INSTANCES_URL/$name.json.gz"
    if !isfile(filename)
        if !quiet
            @info "Downloading: $(url)"
        end
        dpath = download(url)
        mkpath(dirname(filename))
        cp(dpath, filename)
        json = _read_json(filename)
        if "SOURCE" in keys(json) && !quiet
            @info "If you use this instance in your research, please cite:\n\n$(json["SOURCE"])\n"
        end
    end
    return UnitCommitment.read(filename)
end

"""
    read(path::AbstractString)::UnitCommitmentInstance

Read instance from a file. The file may be gzipped.

# Example

```julia
instance = UnitCommitment.read("/path/to/input.json.gz")
```
"""
function read(path::AbstractString)::UnitCommitmentInstance
    if endswith(path, ".gz")
        return _read(gzopen(path))
    else
        return _read(open(path))
    end
end

function _read(file::IO)::UnitCommitmentInstance
    return _from_json(
        JSON.parse(file, dicttype = () -> DefaultOrderedDict(nothing)),
    )
end

function _read_json(path::String)::OrderedDict
    if endswith(path, ".gz")
        file = GZip.gzopen(path)
    else
        file = open(path)
    end
    return JSON.parse(file, dicttype = () -> DefaultOrderedDict(nothing))
end

function _from_json(json; repair = true)
    _migrate(json)
    units = Unit[]
    buses = Bus[]
    contingencies = Contingency[]
    lines = TransmissionLine[]
    loads = PriceSensitiveLoad[]
    reserves = Reserve[]
    profiled_units = ProfiledUnit[]

    function scalar(x; default = nothing)
        x !== nothing || return default
        return x
    end

    time_horizon = json["Parameters"]["Time (h)"]
    if time_horizon === nothing
        time_horizon = json["Parameters"]["Time horizon (h)"]
    end
    time_horizon !== nothing || error("Missing parameter: Time horizon (h)")
    time_step = scalar(json["Parameters"]["Time step (min)"], default = 60)
    (60 % time_step == 0) ||
        error("Time step $time_step is not a divisor of 60")
    time_multiplier = 60 ÷ time_step
    T = time_horizon * time_multiplier

    name_to_bus = Dict{String,Bus}()
    name_to_line = Dict{String,TransmissionLine}()
    name_to_unit = Dict{String,Unit}()
    name_to_reserve = Dict{String,Reserve}()

    function timeseries(x; default = nothing)
        x !== nothing || return default
        x isa Array || return [x for t in 1:T]
        return x
    end

    # Read parameters
    power_balance_penalty = timeseries(
        json["Parameters"]["Power balance penalty (\$/MW)"],
        default = [1000.0 for t in 1:T],
    )
    # Penalty price for shortage in meeting system-wide flexiramp requirements
    flexiramp_shortfall_penalty = timeseries(
        json["Parameters"]["Flexiramp penalty (\$/MW)"],
        default = [500.0 for t in 1:T],
    )
    shortfall_penalty = timeseries(
        json["Parameters"]["Reserve shortfall penalty (\$/MW)"],
        default = [-1.0 for t in 1:T],
    )

    # Read buses
    for (bus_name, dict) in json["Buses"]
        bus = Bus(
            bus_name,
            length(buses),
            timeseries(dict["Load (MW)"]),
            Unit[],
            ProfiledUnit[],
            PriceSensitiveLoad[],
        )
        name_to_bus[bus_name] = bus
        push!(buses, bus)
    end

    # Read reserves
    if "Reserves" in keys(json)
        for (reserve_name, dict) in json["Reserves"]
            r = Reserve(
                name = reserve_name,
                type = lowercase(dict["Type"]),
                amount = timeseries(dict["Amount (MW)"]),
                units = [],
                shortfall_penalty = scalar(
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
        unit_type = scalar(dict["Type"], default = nothing)
        unit_type !== nothing || error("unit $unit_name has no type specified")
        bus = name_to_bus[dict["Bus"]]

        if lowercase(unit_type) === "thermal"
            # Read production cost curve
            K = length(dict["Production cost curve (MW)"])
            curve_mw = hcat(
                [timeseries(dict["Production cost curve (MW)"][k]) for k in 1:K]...,
            )
            curve_cost = hcat(
                [timeseries(dict["Production cost curve (\$)"][k]) for k in 1:K]...,
            )
            min_power = curve_mw[:, 1]
            max_power = curve_mw[:, K]
            min_power_cost = curve_cost[:, 1]
            segments = CostSegment[]
            for k in 2:K
                amount = curve_mw[:, k] - curve_mw[:, k-1]
                cost = (curve_cost[:, k] - curve_cost[:, k-1]) ./ amount
                replace!(cost, NaN => 0.0)
                push!(segments, CostSegment(amount, cost))
            end

            # Read startup costs
            startup_delays = scalar(dict["Startup delays (h)"], default = [1])
            startup_costs = scalar(dict["Startup costs (\$)"], default = [0.0])
            startup_categories = StartupCategory[]
            for k in 1:length(startup_delays)
                push!(
                    startup_categories,
                    StartupCategory(
                        startup_delays[k] .* time_multiplier,
                        startup_costs[k],
                    ),
                )
            end

            # Read reserve eligibility
            unit_reserves = Reserve[]
            if "Reserve eligibility" in keys(dict)
                unit_reserves =
                    [name_to_reserve[n] for n in dict["Reserve eligibility"]]
            end

            # Read and validate initial conditions
            initial_power = scalar(dict["Initial power (MW)"], default = nothing)
            initial_status = scalar(dict["Initial status (h)"], default = nothing)
            if initial_power === nothing
                initial_status === nothing ||
                    error("unit $unit_name has initial status but no initial power")
            else
                initial_status !== nothing ||
                    error("unit $unit_name has initial power but no initial status")
                initial_status != 0 ||
                    error("unit $unit_name has invalid initial status")
                if initial_status < 0 && initial_power > 1e-3
                    error("unit $unit_name has invalid initial power")
                end
                initial_status *= time_multiplier
            end

            unit = Unit(
                unit_name,
                bus,
                max_power,
                min_power,
                timeseries(dict["Must run?"], default = [false for t in 1:T]),
                min_power_cost,
                segments,
                scalar(dict["Minimum uptime (h)"], default = 1) * time_multiplier,
                scalar(dict["Minimum downtime (h)"], default = 1) * time_multiplier,
                scalar(dict["Ramp up limit (MW)"], default = 1e6),
                scalar(dict["Ramp down limit (MW)"], default = 1e6),
                scalar(dict["Startup limit (MW)"], default = 1e6),
                scalar(dict["Shutdown limit (MW)"], default = 1e6),
                initial_status,
                initial_power,
                startup_categories,
                unit_reserves,
            )
            push!(bus.units, unit)
            for r in unit_reserves
                push!(r.units, unit)
            end
            name_to_unit[unit_name] = unit
            push!(units, unit)
        elseif lowercase(unit_type) === "profiled"
            bus = name_to_bus[dict["Bus"]]
            pu = ProfiledUnit(
                unit_name,
                bus,
                timeseries(dict["Maximum power (MW)"]),
                timeseries(dict["Cost (\$/MW)"])
            )
            push!(bus.profiled_units, pu)
            push!(profiled_units, pu)
        else
            error("unit $unit_name has an invalid type")
        end
    end

    # Read transmission lines
    if "Transmission lines" in keys(json)
        for (line_name, dict) in json["Transmission lines"]
            line = TransmissionLine(
                line_name,
                length(lines) + 1,
                name_to_bus[dict["Source bus"]],
                name_to_bus[dict["Target bus"]],
                scalar(dict["Reactance (ohms)"]),
                scalar(dict["Susceptance (S)"]),
                timeseries(
                    dict["Normal flow limit (MW)"],
                    default = [1e8 for t in 1:T],
                ),
                timeseries(
                    dict["Emergency flow limit (MW)"],
                    default = [1e8 for t in 1:T],
                ),
                timeseries(
                    dict["Flow limit penalty (\$/MW)"],
                    default = [5000.0 for t in 1:T],
                ),
            )
            name_to_line[line_name] = line
            push!(lines, line)
        end
    end

    # Read contingencies
    if "Contingencies" in keys(json)
        for (cont_name, dict) in json["Contingencies"]
            affected_units = Unit[]
            affected_lines = TransmissionLine[]
            if "Affected lines" in keys(dict)
                affected_lines =
                    [name_to_line[l] for l in dict["Affected lines"]]
            end
            if "Affected units" in keys(dict)
                affected_units =
                    [name_to_unit[u] for u in dict["Affected units"]]
            end
            cont = Contingency(cont_name, affected_lines, affected_units)
            push!(contingencies, cont)
        end
    end

    # Read price-sensitive loads
    if "Price-sensitive loads" in keys(json)
        for (load_name, dict) in json["Price-sensitive loads"]
            bus = name_to_bus[dict["Bus"]]
            load = PriceSensitiveLoad(
                load_name,
                bus,
                timeseries(dict["Demand (MW)"]),
                timeseries(dict["Revenue (\$/MW)"]),
            )
            push!(bus.price_sensitive_loads, load)
            push!(loads, load)
        end
    end

    instance = UnitCommitmentInstance(
        buses_by_name = Dict(b.name => b for b in buses),
        buses = buses,
        contingencies_by_name = Dict(c.name => c for c in contingencies),
        contingencies = contingencies,
        lines_by_name = Dict(l.name => l for l in lines),
        lines = lines,
        power_balance_penalty = power_balance_penalty,
        price_sensitive_loads_by_name = Dict(ps.name => ps for ps in loads),
        price_sensitive_loads = loads,
        reserves = reserves,
        reserves_by_name = name_to_reserve,
        shortfall_penalty = shortfall_penalty,
        flexiramp_shortfall_penalty = flexiramp_shortfall_penalty,
        time = T,
        units_by_name = Dict(g.name => g for g in units),
        units = units,
        profiled_units_by_name = Dict(pu.name => pu for pu in profiled_units),
        profiled_units = profiled_units,
    )
    if repair
        UnitCommitment.repair!(instance)
    end
    return instance
end
