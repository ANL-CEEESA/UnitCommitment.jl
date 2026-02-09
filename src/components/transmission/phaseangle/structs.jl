# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

Base.@kwdef mutable struct TransmissionLine
    name::String
    offset::Int
    source::Bus
    target::Bus
    susceptance::Float64
    normal_flow_limit::Vector{Float64}
    emergency_flow_limit::Vector{Float64}
    flow_limit_penalty::Vector{Float64}
    invest::Vector{Float64}
    max_copy::Int
end

Base.@kwdef struct PhaseAngleTransmissionExt <: UnitCommitmentExtension
    phase_angle_limit::Float64 = pi
    bigM::Float64 = 1e6
end
