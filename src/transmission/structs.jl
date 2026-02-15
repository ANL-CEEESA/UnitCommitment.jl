# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

abstract type TransmissionExtension <: UnitCommitmentExtension end

extension_slot(::TransmissionExtension) = :transmission

Base.@kwdef mutable struct Branch
    name::String
    offset::Int
    source::Bus
    target::Bus
    resistance::Float64 = 0.0
    reactance::Float64 = 0.0
    susceptance::Float64 = 0.0
    shunt_conductance::Float64 = 0.0
    shunt_susceptance::Float64 = 0.0
    tap_ratio::Float64 = 1.0
    phase_shift::Float64 = 0.0
    normal_flow_limit::Vector{Float64}
    emergency_flow_limit::Vector{Float64}
    flow_limit_penalty::Vector{Float64}
    angle_diff_min::Float64 = -Inf
    angle_diff_max::Float64 = Inf
    invest::Vector{Float64} = [0.0]
    max_copy::Int = 1
end

Base.@kwdef mutable struct Contingency
    name::String
    branches::Vector{Branch}
end

Base.@kwdef mutable struct ShuntDevice
    name::String
    bus::Bus
    conductance::Float64
    susceptance::Float64
    status::Vector{Bool}
end
