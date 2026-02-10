# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

abstract type UnitCommitmentExtension end
abstract type SolutionMethod end

Base.@kwdef mutable struct UnitCommitmentScenario
    name::String
    data::Dict = Dict()
end

Base.getindex(sc::UnitCommitmentScenario, key) = sc.data[key]
Base.setindex!(sc::UnitCommitmentScenario, value, key) = sc.data[key] = value
Base.haskey(sc::UnitCommitmentScenario, key) = haskey(sc.data, key)
Base.get(sc::UnitCommitmentScenario, key, default) = get(sc.data, key, default)

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
