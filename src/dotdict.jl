# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

struct DotDict
    inner::Dict
end

DotDict() = DotDict(Dict())

function Base.setproperty!(d::DotDict, key::Symbol, value)
    setindex!(getfield(d, :inner), value, key)
end

function Base.getproperty(d::DotDict, key::Symbol)
    (key == :inner ? getfield(d, :inner) : d.inner[key])
end

function Base.getindex(d::DotDict, key::Int64)
    d.inner[Symbol(key)]
end

function Base.getindex(d::DotDict, key::Symbol)
    d.inner[key]
end

function Base.keys(d::DotDict)
    keys(d.inner)
end

function Base.values(d::DotDict)
    values(d.inner)
end

function Base.iterate(d::DotDict)
    iterate(values(d.inner))
end

function Base.iterate(d::DotDict, v::Int64)
    iterate(values(d.inner), v)
end

function Base.length(d::DotDict)
    length(values(d.inner))
end

function Base.show(io::IO, d::DotDict)
    print(io, "DotDict with $(length(keys(d.inner))) entries:\n")
    count = 0
    for k in keys(d.inner)
        count += 1
        if count > 10
            print(io, "  ...\n")
            break
        end
        print(io, "  :$(k) => $(d.inner[k])\n")
    end
end

function recursive_to_dot_dict(el)
    if typeof(el) == Dict{String, Any}
        return DotDict(Dict(Symbol(k) => recursive_to_dot_dict(el[k]) for k in keys(el)))
    else
        return el
    end
end

export recursive_to_dot_dict