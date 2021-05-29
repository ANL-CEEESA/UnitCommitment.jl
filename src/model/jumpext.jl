# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

# This file extends some JuMP functions so that decision variables can be safely
# replaced by (constant) floating point numbers.

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
