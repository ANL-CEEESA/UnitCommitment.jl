# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

Base.@kwdef mutable struct VirtualTransaction
    name::String
    type::Symbol              # :inc, :dec, or :utc
    bus_source::Bus           # source bus (= bus for INC/DEC)
    bus_sink::Bus             # sink bus (= bus for INC/DEC)
    price::Vector{Float64}    # offer/bid price per time step
    max_quantity::Vector{Float64}  # max MW per time step
end

struct VirtualTransactionsExt <: UnitCommitmentExtension end
