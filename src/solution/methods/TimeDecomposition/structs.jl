# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

import ..SolutionMethod
import ..Formulation
"""
    mutable struct TimeDecomposition <: SolutionMethod
        time_window::Int
        time_increment::Int
        inner_method::SolutionMethod
        formulation::Formulation
    end

Time decomposition method to solve a problem with moving time window.

Fields
------

- `time_window`:
    the time window of each sub-problem during the entire optimization procedure.
- `time_increment`: 
    the time incremented to the next sub-problem.
- `inner_method`: 
    method to solve each sub-problem.
- `formulation`:
    problem formulation.

"""
Base.@kwdef mutable struct TimeDecomposition <: SolutionMethod
    time_window::Int
    time_increment::Int
    inner_method::SolutionMethod
    formulation::Formulation
end
