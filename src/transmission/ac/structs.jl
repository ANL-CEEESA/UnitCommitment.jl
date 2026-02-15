# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

abstract type ACFormulation end

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
