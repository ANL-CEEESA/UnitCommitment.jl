# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

mutable struct Bus
    name::String
    offset::Int
    load::Vector{Float64}
    reactive_load::Vector{Float64}
    vmin::Float64
    vmax::Float64
    bus_type::String
end
