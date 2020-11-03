# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using Printf
using JSON
using DataStructures
import Base: getindex, time
import GZip


mutable struct Bus
    name::String
    offset::Int
    load::Array{Float64}
    units::Array
    price_sensitive_loads::Array
end


mutable struct CostSegment
    mw::Array{Float64}
    cost::Array{Float64}
end


mutable struct StartupCategory
    delay::Int
    cost::Float64
end


mutable struct Unit
    name::String
    bus::Bus
    max_power::Array{Float64}
    min_power::Array{Float64}
    must_run::Array{Bool}
    min_power_cost::Array{Float64}
    cost_segments::Array{CostSegment}
    min_uptime::Int
    min_downtime::Int
    ramp_up_limit::Float64
    ramp_down_limit::Float64
    startup_limit::Float64
    shutdown_limit::Float64
    initial_status::Union{Int,Nothing}
    initial_power::Union{Float64,Nothing}
    provides_spinning_reserves::Array{Bool}
    startup_categories::Array{StartupCategory}
end


mutable struct TransmissionLine
    name::String
    offset::Int
    source::Bus
    target::Bus
    reactance::Float64
    susceptance::Float64
    normal_flow_limit::Array{Float64}
    emergency_flow_limit::Array{Float64}
    flow_limit_penalty::Array{Float64}
end


mutable struct Reserves
    spinning::Array{Float64}
end


mutable struct Contingency
    name::String
    lines::Array{TransmissionLine}
    units::Array{Unit}
end


mutable struct PriceSensitiveLoad
    name::String
    bus::Bus
    demand::Array{Float64}
    revenue::Array{Float64}
end


mutable struct UnitCommitmentInstance
    time::Int
    power_balance_penalty::Array{Float64}
    units::Array{Unit}
    buses::Array{Bus}
    lines::Array{TransmissionLine}
    reserves::Reserves
    contingencies::Array{Contingency}
    price_sensitive_loads::Array{PriceSensitiveLoad}
end


function Base.show(io::IO, instance::UnitCommitmentInstance)
    print(io, "UnitCommitmentInstance with ")
    print(io, "$(length(instance.units)) units, ")
    print(io, "$(length(instance.buses)) buses, ")
    print(io, "$(length(instance.lines)) lines, ")
    print(io, "$(length(instance.contingencies)) contingencies, ")
    print(io, "$(length(instance.price_sensitive_loads)) price sensitive loads")
end


function read_benchmark(name::AbstractString) :: UnitCommitmentInstance
    basedir = dirname(@__FILE__)
    return UnitCommitment.read("$basedir/../instances/$name.json.gz")
end


function read(path::AbstractString)::UnitCommitmentInstance
    if endswith(path, ".gz")
        return read(GZip.gzopen(path))
    else
        return read(open(path))
    end
end


function read(file::IO)::UnitCommitmentInstance
    return from_json(JSON.parse(file, dicttype=()->DefaultOrderedDict(nothing)))
end
    
function from_json(json; fix=true)
    units = Unit[]
    buses = Bus[]
    contingencies = Contingency[]
    lines = TransmissionLine[]
    loads = PriceSensitiveLoad[]
    T = json["Parameters"]["Time (h)"]
    
    name_to_bus = Dict{String, Bus}()
    name_to_line = Dict{String, TransmissionLine}()
    name_to_unit = Dict{String, Unit}()
    
    function timeseries(x; default=nothing)
        x != nothing || return default
        x isa Array || return [x for t in 1:T]
        return x
    end
    
    function scalar(x; default=nothing)
        x != nothing || return default
        x
    end
    
    # Read parameters
    power_balance_penalty = timeseries(json["Parameters"]["Power balance penalty (\$/MW)"],
                                       default=[1000.0 for t in 1:T])
    
    # Read buses
    for (bus_name, dict) in json["Buses"]
        bus = Bus(bus_name,
                  length(buses),
                  timeseries(dict["Load (MW)"]),
                  Unit[],
                  PriceSensitiveLoad[])
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
            push!(startup_categories, StartupCategory(startup_delays[k],
                                                      startup_costs[k]))
        end
        
        # Read and validate initial conditions
        initial_power = scalar(dict["Initial power (MW)"], default=nothing)
        initial_status = scalar(dict["Initial status (h)"], default=nothing)
        if initial_power == nothing
            initial_status == nothing || error("unit $unit_name has initial status but no initial power")
        else
            initial_status != nothing || error("unit $unit_name has initial power but no initial status")
            initial_status != 0 || error("unit $unit_name has invalid initial status")
            if initial_status < 0 && initial_power > 1e-3
                error("unit $unit_name has invalid initial power")
            end
        end
        
        unit = Unit(unit_name,
                    bus,
                    max_power,
                    min_power,
                    timeseries(dict["Must run?"], default=[false for t in 1:T]),
                    min_power_cost,
                    segments,
                    scalar(dict["Minimum uptime (h)"], default=1),
                    scalar(dict["Minimum downtime (h)"], default=1),
                    scalar(dict["Ramp up limit (MW)"], default=1e6),
                    scalar(dict["Ramp down limit (MW)"], default=1e6),
                    scalar(dict["Startup limit (MW)"], default=1e6),
                    scalar(dict["Shutdown limit (MW)"], default=1e6),
                    initial_status,
                    initial_power,
                    timeseries(dict["Provides spinning reserves?"],
                               default=[true for t in 1:T]),
                    startup_categories)
        push!(bus.units, unit)
        name_to_unit[unit_name] = unit
        push!(units, unit)
    end
    
    # Read reserves
    reserves = Reserves(zeros(T))
    if "Reserves" in keys(json)
        reserves.spinning = timeseries(json["Reserves"]["Spinning (MW)"],
                                       default=zeros(T))
    end
    
    # Read transmission lines
    if "Transmission lines" in keys(json)
        for (line_name, dict) in json["Transmission lines"]
            line = TransmissionLine(line_name,
                                    length(lines) + 1,
                                    name_to_bus[dict["Source bus"]],
                                    name_to_bus[dict["Target bus"]],
                                    scalar(dict["Reactance (ohms)"]),
                                    scalar(dict["Susceptance (S)"]),
                                    timeseries(dict["Normal flow limit (MW)"],
                                               default=[1e8 for t in 1:T]),
                                    timeseries(dict["Emergency flow limit (MW)"],
                                               default=[1e8 for t in 1:T]),
                                    timeseries(dict["Flow limit penalty (\$/MW)"],
                                               default=[5000.0 for t in 1:T]))
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
            load = PriceSensitiveLoad(load_name,
                                      bus,
                                      timeseries(dict["Demand (MW)"]),
                                      timeseries(dict["Revenue (\$/MW)"]),
                                     )
            push!(bus.price_sensitive_loads, load)
            push!(loads, load)
        end
    end
    
    instance = UnitCommitmentInstance(T,
                                      power_balance_penalty,
                                      units,
                                      buses,
                                      lines,
                                      reserves,
                                      contingencies,
                                      loads)
    if fix
        UnitCommitment.fix!(instance)
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
function slice(instance::UnitCommitmentInstance, range::UnitRange{Int})::UnitCommitmentInstance
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
