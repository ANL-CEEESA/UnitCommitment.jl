# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

mutable struct Bus
    name::String
    offset::Int
    load::Vector{Float64}
    thermal_units::Vector
    price_sensitive_loads::Vector
    profiled_units::Vector
end

mutable struct CostSegment
    mw::Vector{Float64}
    cost::Vector{Float64}
end

mutable struct StartupCategory
    delay::Int
    cost::Float64
end

Base.@kwdef mutable struct Reserve
    name::String
    type::String
    amount::Vector{Float64}
    thermal_units::Vector
    shortfall_penalty::Float64
end

mutable struct ThermalUnit
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
    startup_categories::Vector{StartupCategory}
    reserves::Vector{Reserve}
    commitment_status::Vector{Union{Bool,Nothing}}
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

mutable struct Contingency
    name::String
    lines::Vector{TransmissionLine}
    thermal_units::Vector{ThermalUnit}
end

mutable struct PriceSensitiveLoad
    name::String
    bus::Bus
    demand::Vector{Float64}
    revenue::Vector{Float64}
end

mutable struct ProfiledUnit
    name::String
    bus::Bus
    min_power::Vector{Float64}
    capacity::Vector{Float64}
    cost::Vector{Float64}
end

Base.@kwdef mutable struct UnitCommitmentScenario
    buses_by_name::Dict{AbstractString,Bus}
    buses::Vector{Bus}
    contingencies_by_name::Dict{AbstractString,Contingency}
    contingencies::Vector{Contingency}
    isf::Array{Float64,2}
    lines_by_name::Dict{AbstractString,TransmissionLine}
    lines::Vector{TransmissionLine}
    lodf::Array{Float64,2}
    name::String
    power_balance_penalty::Vector{Float64}
    price_sensitive_loads_by_name::Dict{AbstractString,PriceSensitiveLoad}
    price_sensitive_loads::Vector{PriceSensitiveLoad}
    probability::Float64
    profiled_units_by_name::Dict{AbstractString,ProfiledUnit}
    profiled_units::Vector{ProfiledUnit}
    reserves_by_name::Dict{AbstractString,Reserve}
    reserves::Vector{Reserve}
    thermal_units_by_name::Dict{AbstractString,ThermalUnit}
    thermal_units::Vector{ThermalUnit}
    time::Int
end

Base.@kwdef mutable struct UnitCommitmentInstance
    time::Int
    scenarios::Vector{UnitCommitmentScenario}
end

function Base.show(io::IO, instance::UnitCommitmentInstance)
    sc = instance.scenarios[1]
    print(io, "UnitCommitmentInstance(")
    print(io, "$(length(instance.scenarios)) scenarios, ")
    print(io, "$(length(sc.thermal_units)) thermal units, ")
    print(io, "$(length(sc.profiled_units)) profiled units, ")
    print(io, "$(length(sc.buses)) buses, ")
    print(io, "$(length(sc.lines)) lines, ")
    print(io, "$(length(sc.contingencies)) contingencies, ")
    print(io, "$(length(sc.price_sensitive_loads)) price sensitive loads, ")
    print(io, "$(instance.time) time steps")
    print(io, ")")
    return
end

export UnitCommitmentInstance
