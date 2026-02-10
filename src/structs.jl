# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

abstract type UnitCommitmentExtension end
abstract type SolutionMethod end

Base.@kwdef mutable struct UnitCommitmentScenario
    name::String
    investment_cost_weight::Float64
    power_balance_penalty::Vector{Float64}
    probability::Float64
    time::Int
    time_step::Int
    data::Dict = Dict()
end

Base.@kwdef mutable struct UnitCommitmentInstance
    time::Int
    scenarios::Vector{UnitCommitmentScenario}
    extensions::Vector
end

function Base.show(io::IO, instance::UnitCommitmentInstance)
    sc = instance.scenarios[1]
    print(io, "UnitCommitmentInstance(")
    print(io, "$(length(instance.scenarios)) scenarios, ")
    summarize_buses(instance, io)
    for ext in instance.extensions
        summarize(instance, ext, io)
    end
    print(io, "$(instance.time) time steps")
    print(io, ")")
    return
end

export UnitCommitmentInstance
