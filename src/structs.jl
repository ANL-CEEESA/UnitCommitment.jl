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
    extension_slot(ext) -> Union{Symbol, Nothing}

Return the slot that this extension occupies, or `nothing` if it does not
belong to any slot. When merging user-provided extensions with the defaults,
an extension whose slot matches a default extension's slot will **replace**
it, even if the two have different concrete types.

Third-party extensions can participate in the slot system by defining a
method for their type:

```julia
UnitCommitment.extension_slot(::MyTransmissionExt) = :transmission
```
"""
extension_slot(::UnitCommitmentExtension) = nothing

"""
    abstract type SolutionMethod end

Base type for solution methods (e.g. `XavQiuWanThi19`). A solution method
controls how the optimization model is solved, including any decomposition or
callback strategies.
"""
abstract type SolutionMethod end

"""
    DirectMethod <: SolutionMethod

Standard solution method that solves the unit commitment model directly as a
single MILP, without decomposition or lazy constraint generation.
```
"""
struct DirectMethod <: SolutionMethod end

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
    UnitCommitmentInstance(; time, scenarios, extensions, extension_by_slot)

Top-level structure representing a stochastic unit commitment
instance. Use [`UnitCommitment.read`](@ref) or
[`UnitCommitment.read_benchmark`](@ref) to construct instances from JSON files.

# Fields
- `time::Int`: number of time steps.
- `scenarios::Vector{UnitCommitmentScenario}`: one or more scenarios.
- `extensions::Vector`: active extensions that define the model components.
- `extension_by_slot::Dict{Symbol,Any}`: extensions indexed by their slot.
"""
Base.@kwdef mutable struct UnitCommitmentInstance
    time::Int
    scenarios::Vector{UnitCommitmentScenario}
    extensions::Vector
    extension_by_slot::Dict{Symbol,Any} = Dict{Symbol,Any}()
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

"""
    UnitCommitmentModel

Wrapper around a `JuMP.Model` returned by [`build_model`](@ref). Use
`model.inner` to access the underlying JuMP model directly when needed
(e.g. for setting solver attributes or inspecting variables).

# Fields
- `instance::UnitCommitmentInstance`: the problem instance.
- `inner::JuMP.Model`: the underlying JuMP optimization model.
- `data::Dict`: storage for UC.jl-specific data (e.g. extracted solution).
"""
struct UnitCommitmentModel
    instance::UnitCommitmentInstance
    inner::JuMP.Model
    data::Dict
    optimizer::Any
end

export UnitCommitmentModel
