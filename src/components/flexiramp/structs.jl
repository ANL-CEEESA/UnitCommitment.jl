# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

Base.@kwdef mutable struct FlexirampReserve
    name::String
    amount::Vector{Float64}
    thermal_units::Vector
    shortfall_penalty::Float64
end

struct FlexirampExt <: UnitCommitmentExtension end
