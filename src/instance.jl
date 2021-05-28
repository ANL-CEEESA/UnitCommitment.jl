# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using Printf
using JSON
using DataStructures
using GZip
import Base: getindex, time


mutable struct Bus
    name::String
    offset::Int
    load::Vector{Float64}
    units::Vector
    price_sensitive_loads::Vector
end


mutable struct CostSegment
    mw::Vector{Float64}
    cost::Vector{Float64}
end


mutable struct StartupCategory
    delay::Int
    cost::Float64
end


mutable struct Unit
    name::String
    bus::Bus
    max_power::Vector{Float64}
    min_power::Vector{Float64}
    must_run::Vector{Bool}
    min_power_cost::Vector{Float64}
    cost_segments::Vector{CostSegment}
    min_uptime::Int
    min_downtime::Int
    ramp_up_limit::Float64
    ramp_down_limit::Float64
    startup_limit::Float64
    shutdown_limit::Float64
    initial_status::Union{Int,Nothing}
    initial_power::Union{Float64,Nothing}
    provides_spinning_reserves::Vector{Bool}
    startup_categories::Vector{StartupCategory}
end


mutable struct TransmissionLine
    name::String
    offset::Int
    source::Bus
    target::Bus
    reactance::Float64
    susceptance::Float64
    normal_flow_limit::Vector{Float64}
    emergency_flow_limit::Vector{Float64}
    flow_limit_penalty::Vector{Float64}
end


mutable struct Reserves
    spinning::Vector{Float64}
end


mutable struct Contingency
    name::String
    lines::Vector{TransmissionLine}
    units::Vector{Unit}
end


mutable struct PriceSensitiveLoad
    name::String
    bus::Bus
    demand::Vector{Float64}
    revenue::Vector{Float64}
end


mutable struct UnitCommitmentInstance
    time::Int
    power_balance_penalty::Vector{Float64}
    units::Vector{Unit}
    buses::Vector{Bus}
    lines::Vector{TransmissionLine}
    reserves::Reserves
    contingencies::Vector{Contingency}
    price_sensitive_loads::Vector{PriceSensitiveLoad}
end


function Base.show(io::IO, instance::UnitCommitmentInstance)
    print(io, "UnitCommitmentInstance(")
    print(io, "$(length(instance.units)) units, ")
    print(io, "$(length(instance.buses)) buses, ")
    print(io, "$(length(instance.lines)) lines, ")
    print(io, "$(length(instance.contingencies)) contingencies, ")
    print(io, "$(length(instance.price_sensitive_loads)) price sensitive loads, ")
    print(io, "$(instance.time) time steps")
    print(io, ")")
end


function read_benchmark(name::AbstractString) :: UnitCommitmentInstance
    basedir = dirname(@__FILE__)
    return UnitCommitment.read("$basedir/../instances/$name.json.gz")
end


function read(path::AbstractString)::UnitCommitmentInstance
    if endswith(path, ".gz")
        return _read(gzopen(path))
    else
        return _read(open(path))
    end
end


function _read(file::IO)::UnitCommitmentInstance
    return _from_json(JSON.parse(file, dicttype=()->DefaultOrderedDict(nothing)))
end
    

function _from_json(json; repair=true)
    units = Unit[]
    buses = Bus[]
    contingencies = Contingency[]
    lines = TransmissionLine[]
    loads = PriceSensitiveLoad[]

    function scalar(x; default=nothing)
        x !== nothing || return default
        x
    end
    
    time_horizon = json["Parameters"]["Time (h)"]
    if time_horizon === nothing
        time_horizon = json["Parameters"]["Time horizon (h)"]
    end
    time_horizon !== nothing || error("Missing required parameter: Time horizon (h)")
    time_step = scalar(json["Parameters"]["Time step (min)"], default=60)
    (60 % time_step == 0) || error("Time step $time_step is not a divisor of 60")
    time_multiplier = 60 ÷ time_step
    T = time_horizon * time_multiplier
    
    name_to_bus = Dict{String, Bus}()
    name_to_line = Dict{String, TransmissionLine}()
    name_to_unit = Dict{String, Unit}()
    
    function timeseries(x; default=nothing)
        x !== nothing || return default
        x isa Array || return [x for t in 1:T]
        return x
    end
    
    # Read parameters
    power_balance_penalty = timeseries(
        json["Parameters"]["Power balance penalty (\$/MW)"],
        default=[1000.0 for t in 1:T],
    )
    
    # Read buses
    for (bus_name, dict) in json["Buses"]
        bus = Bus(
            bus_name,
            length(buses),
            timeseries(dict["Load (MW)"]),
            Unit[],
            PriceSensitiveLoad[],
        )
        name_to_bus[bus_name] = bus
        push!(buses, bus)
    end
    
    # Read units
    for (unit_name, dict) in json["Generators"]
        bus = name_to_bus[dict["Bus"]]
        
        # Read production cost curve
        K = length(dict["Production cost curve (MW)"])
        curve_mw   = hcat([timeseries(dict["Production cost curve (MW)"][k]) for k in 1:K]...)
        curve_cost = hcat([timeseries(dict["Production cost curve (\$)"][k]) for k in 1:K]...)
        min_power = curve_mw[:, 1]
        max_power = curve_mw[:, K]
        min_power_cost = curve_cost[:, 1]
        segments = CostSegment[]
        for k in 2:K
            amount = curve_mw[:, k] - curve_mw[:, k-1]
            cost = (curve_cost[:, k] - curve_cost[:, k-1]) ./ amount
            replace!(cost, NaN=>0.0)
            push!(segments, CostSegment(amount, cost))
        end
        
        # Read startup costs
        startup_delays = scalar(dict["Startup delays (h)"], default=[1])
        startup_costs  = scalar(dict["Startup costs (\$)"], default=[0.])
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
        
        # Read and validate initial conditions
        initial_power = scalar(dict["Initial power (MW)"], default=nothing)
        initial_status = scalar(dict["Initial status (h)"], default=nothing)
        if initial_power === nothing
            initial_status === nothing || error("unit $unit_name has initial status but no initial power")
        else
            initial_status !== nothing || error("unit $unit_name has initial power but no initial status")
            initial_status != 0 || error("unit $unit_name has invalid initial status")
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
            timeseries(dict["Must run?"], default=[false for t in 1:T]),
            min_power_cost,
            segments,
            scalar(dict["Minimum uptime (h)"], default=1) * time_multiplier,
            scalar(dict["Minimum downtime (h)"], default=1) * time_multiplier,
            scalar(dict["Ramp up limit (MW)"], default=1e6),
            scalar(dict["Ramp down limit (MW)"], default=1e6),
            scalar(dict["Startup limit (MW)"], default=1e6),
            scalar(dict["Shutdown limit (MW)"], default=1e6),
            initial_status,
            initial_power,
            timeseries(
                dict["Provides spinning reserves?"],
                default=[true for t in 1:T],
            ),
            startup_categories,
        )
        push!(bus.units, unit)
        name_to_unit[unit_name] = unit
        push!(units, unit)
    end
    
    # Read reserves
    reserves = Reserves(zeros(T))
    if "Reserves" in keys(json)
        reserves.spinning = timeseries(
            json["Reserves"]["Spinning (MW)"],
            default=zeros(T),
        )
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
                    default=[1e8 for t in 1:T],
                ),
                timeseries(
                    dict["Emergency flow limit (MW)"],
                    default=[1e8 for t in 1:T],
                ),
                timeseries(
                    dict["Flow limit penalty (\$/MW)"],
                    default=[5000.0 for t in 1:T],
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
                affected_lines = [name_to_line[l] for l in dict["Affected lines"]]
            end
            if "Affected units" in keys(dict)
                affected_units = [name_to_unit[u] for u in dict["Affected units"]]
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
        T,
        power_balance_penalty,
        units,
        buses,
        lines,
        reserves,
        contingencies,
        loads,
    )
    if repair
        UnitCommitment.repair!(instance)
    end
    return instance
end


"""
    slice(instance, range)

Creates a new instance, with only a subset of the time periods.
This function does not modify the provided instance. The initial
conditions are also not modified.

Example
-------

    # Build a 2-hour UC instance
    instance = UnitCommitment.read_benchmark("test/case14")
    modified = UnitCommitment.slice(instance, 1:2)

"""
function slice(
    instance::UnitCommitmentInstance,
    range::UnitRange{Int},
)::UnitCommitmentInstance
    modified = deepcopy(instance)
    modified.time = length(range)
    modified.power_balance_penalty = modified.power_balance_penalty[range]
    modified.reserves.spinning = modified.reserves.spinning[range]
    for u in modified.units
        u.max_power = u.max_power[range]
        u.min_power = u.min_power[range]
        u.must_run = u.must_run[range]
        u.min_power_cost = u.min_power_cost[range]
        u.provides_spinning_reserves = u.provides_spinning_reserves[range]
        for s in u.cost_segments
            s.mw = s.mw[range]
            s.cost = s.cost[range]
        end
    end
    for b in modified.buses
        b.load = b.load[range]
    end
    for l in modified.lines
        l.normal_flow_limit = l.normal_flow_limit[range]
        l.emergency_flow_limit = l.emergency_flow_limit[range]
        l.flow_limit_penalty = l.flow_limit_penalty[range]
    end
    for ps in modified.price_sensitive_loads
        ps.demand = ps.demand[range]
        ps.revenue = ps.revenue[range]
    end
    return modified
end


export UnitCommitmentInstance
