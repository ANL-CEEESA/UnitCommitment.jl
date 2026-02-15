# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

abstract type ACFormulation end

Base.@kwdef mutable struct ACBranch
    name::String
    offset::Int
    source::Bus
    target::Bus
    resistance::Float64
    reactance::Float64
    shunt_conductance::Float64
    shunt_susceptance::Float64
    tap_ratio::Float64
    phase_shift::Float64
    is_transformer::Bool
    normal_flow_limit::Vector{Float64}
    emergency_flow_limit::Vector{Float64}
    flow_limit_penalty::Vector{Float64}
    angle_diff_min::Float64
    angle_diff_max::Float64
end

Base.@kwdef mutable struct ShuntDevice
    name::String
    bus::Bus
    conductance::Float64
    susceptance::Float64
    status::Vector{Bool}
end

Base.@kwdef struct ACTransmissionExt <: UnitCommitmentExtension
    formulation::ACFormulation = ACRectangular()
end

extension_slot(::ACTransmissionExt) = :transmission
