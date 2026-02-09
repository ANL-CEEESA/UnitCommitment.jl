# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

mutable struct PriceSensitiveLoad
    name::String
    bus::Bus
    demand::Vector{Float64}
    revenue::Vector{Float64}
end

struct PriceSensitiveLoadsExt <: UnitCommitmentExtension end
