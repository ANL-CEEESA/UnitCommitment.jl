# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

Base.@kwdef mutable struct Interface
    name::String
    offset::Int
    lines::Vector{TransmissionLine}
    weight_by_line::Dict{TransmissionLine,Float64}
    net_flow_ub::Vector{Float64}
    net_flow_lb::Vector{Float64}
    flow_limit_penalty::Vector{Float64}
end

struct InterfaceLimitsExt <: UnitCommitmentExtension end
struct NoInterfaceLimits <: UnitCommitmentExtension end

extension_slot(::InterfaceLimitsExt) = :interface
extension_slot(::NoInterfaceLimits) = :interface
