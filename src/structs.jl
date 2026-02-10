# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

"""
    abstract type UnitCommitmentExtension end

Base type for all extensions. Extensions add components (e.g. thermal units,
storage, transmission lines) to the model by implementing lifecycle hooks such
as `read_json`, `build_model`, `solution`, `validate` and `summarize`.
"""
abstract type UnitCommitmentExtension end

"""
    abstract type SolutionMethod end

Base type for solution methods (e.g. `XavQiuWanThi2024`). A solution method
controls how the optimization model is solved, including any decomposition or
callback strategies.
"""
abstract type SolutionMethod end

"""
    UnitCommitmentScenario(; name)

A single scenario in a unit commitment instance. Component data (buses, thermal
units, storage, etc.) is stored in the `data` dictionary and accessed via
bracket syntax:

```julia
sc[:bus]            # get bus data
sc[:time] = 24      # set time periods
haskey(sc, :bus)    # check if key exists
```

# Fields
- `name::String`: scenario identifier.
- `data::Dict`: extensible storage for component data populated by extensions.
"""
Base.@kwdef mutable struct UnitCommitmentScenario
    name::String
    data::Dict = Dict()
end

Base.getindex(sc::UnitCommitmentScenario, key) = sc.data[key]
Base.setindex!(sc::UnitCommitmentScenario, value, key) = sc.data[key] = value
Base.haskey(sc::UnitCommitmentScenario, key) = haskey(sc.data, key)
Base.get(sc::UnitCommitmentScenario, key, default) = get(sc.data, key, default)

"""
    UnitCommitmentInstance(; time, scenarios, extensions)

Top-level structure representing a stochastic unit commitment
instance. Use [`UnitCommitment.read`](@ref) or
[`UnitCommitment.read_benchmark`](@ref) to construct instances from JSON files.

# Fields
- `time::Int`: number of time steps.
- `scenarios::Vector{UnitCommitmentScenario}`: one or more scenarios.
- `extensions::Vector`: active extensions that define the model components.
"""
Base.@kwdef mutable struct UnitCommitmentInstance
    time::Int
    scenarios::Vector{UnitCommitmentScenario}
    extensions::Vector
end

function Base.show(io::IO, instance::UnitCommitmentInstance)
    print(io, "UnitCommitmentInstance(")
    print(io, "$(length(instance.scenarios)) scenarios, ")
    summarize_buses(instance, io)
    for ext in instance.extensions
        summarize(instance, ext, io)
    end
    print(io, "$(instance.time) time steps)")
    return
end

export UnitCommitmentInstance
