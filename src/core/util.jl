# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

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
