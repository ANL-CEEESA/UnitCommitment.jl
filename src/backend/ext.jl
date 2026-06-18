# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

function _resolve_struct(d::AbstractDict)
    name = d["type"]
    parts = split(name, ".")
    mod = UnitCommitment
    for p in parts[1:end-1]
        sym = Symbol(p)
        if !isdefined(mod, sym)
            error("Unknown module: $(join(parts[1:end-1], "."))")
        end
        mod = getfield(mod, sym)
    end
    sym = Symbol(parts[end])
    if !isdefined(mod, sym)
        error("Unknown type: $name")
    end
    T = getfield(mod, sym)
    if !(T isa Type)
        error("$name is not a type")
    end
    kwargs = Dict(
        Symbol(k) => (
            v isa AbstractDict && haskey(v, "type") ? _resolve_struct(v) : v
        ) for (k, v) in d if k != "type"
    )
    return T(; kwargs...)
end

function _parse_extensions(configs::Vector)
    extensions = [_resolve_struct(c) for c in configs]
    for ext in extensions
        if !(ext isa UnitCommitmentExtension)
            error("$(typeof(ext)) is not a UnitCommitmentExtension")
        end
    end
    return extensions
end
