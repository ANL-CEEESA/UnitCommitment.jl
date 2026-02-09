# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

Base.@kwdef mutable struct ProfiledUnit
    name::String
    bus::Bus
    min_power::Vector{Float64}
    max_power::Vector{Float64}
    cost::Vector{Float64}
    invest::Vector{Float64}
end

struct ProfiledUnitsExt <: UnitCommitmentExtension end
