# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

Base.@kwdef mutable struct StorageUnit
    name::String
    bus::Bus
    min_level::Vector{Float64}
    max_level::Vector{Float64}
    simultaneous_charge_and_discharge::Vector{Bool}
    charge_cost::Vector{Float64}
    discharge_cost::Vector{Float64}
    charge_efficiency::Vector{Float64}
    discharge_efficiency::Vector{Float64}
    loss_factor::Vector{Float64}
    min_charge_rate::Vector{Float64}
    max_charge_rate::Vector{Float64}
    min_discharge_rate::Vector{Float64}
    max_discharge_rate::Vector{Float64}
    initial_level::Float64
    min_ending_level::Float64
    max_ending_level::Float64
    invest::Vector{Float64}
    qmin::Float64 = 0.0
    qmax::Float64 = 0.0
    apparent_power_limit::Float64 = Inf
end

struct StorageExt <: UnitCommitmentExtension end
