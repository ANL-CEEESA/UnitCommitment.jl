# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using Suppressor

Base.@kwdef mutable struct MIPLearnMethod
    optimizer::Any
    collectors::Any = nothing
    solver::Any = nothing
end
