# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

"""
    to_scalar(x; default=nothing)

Convert a value `x` into a scalar, with a fallback default.

- If `x` is `nothing`, return `default`.
- Otherwise, return `x` as-is.
"""
function to_scalar(x; default = nothing)
    x !== nothing || return default
    return x
end

"""
    to_timeseries(x, T::Int; default=nothing)

Convert a value `x` into a time series vector of length `T`.

- If `x` is `nothing`, return `default`.
- If `x` is a scalar, return a vector repeating `x` for each time step.
- If `x` is already an array, return it as-is.
"""
function to_timeseries(x, T::Int; default = nothing)
    x !== nothing || return default
    x isa Array || return [x for t in 1:T]
    return x
end

function _timeseries(
    model::JuMP.Model,
    sym::Symbol,
    collection,
    T::Int;
    sc = nothing,
)
    isempty(collection) && return OrderedDict{String,Vector{Float64}}()
    vars = model[sym]
    if sc === nothing
        return OrderedDict(
            b.name => [round(value(vars[b.name, t]), digits = 5) for t in 1:T]
            for b in collection
        )
    else
        return OrderedDict(
            b.name => [
                round(value(vars[sc.name, b.name, t]), digits = 5) for t in 1:T
            ] for b in collection
        )
    end
end

# JuMP extensions: Allow decision variables to be safely replaced by constant floats
import JuMP: value, fix, set_name

function value(x::Float64)
    return x
end

function fix(x::Float64, v::Float64; force)
    return abs(x - v) < 1e-6 || error("Value mismatch: $x != $v")
end

function set_name(x::Float64, n::String)
    # nop
end

function _init(model::JuMP.Model, key::Symbol)::OrderedDict
    if !(key in keys(object_dictionary(model)))
        model[key] = OrderedDict()
    end
    return model[key]
end

function _set_names!(model::JuMP.Model)
    @info "Setting variable and constraint names..."
    time_varnames = @elapsed begin
        _set_names!(object_dictionary(model))
    end
    @info @sprintf("Set names in %.2f seconds", time_varnames)
end

function _set_names!(dict::Dict)
    for name in keys(dict)
        dict[name] isa AbstractDict || continue
        for idx in keys(dict[name])
            if dict[name][idx] isa AffExpr
                continue
            end
            idx_str = join(map(string, idx), ",")
            set_name(dict[name][idx], "$name[$idx_str]")
        end
    end
end
