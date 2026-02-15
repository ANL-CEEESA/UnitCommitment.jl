# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

module XavQiuWanThi2019
import ..SolutionMethod
"""
    mutable struct Method
        time_limit::Float64
        gap_limit::Float64
        two_phase_gap::Bool
        max_violations_per_branch::Int
        max_violations_per_period::Int
    end

Lazy constraint solution method described in:

    Xavier, A. S., Qiu, F., Wang, F., & Thimmapuram, P. R. (2019). Transmission
    constraint filtering in large-scale security-constrained unit commitment.
    IEEE Transactions on Power Systems, 34(3), 2457-2460.
    DOI: https://doi.org/10.1109/TPWRS.2019.2892620

Fields
------

- `time_limit`:
    the time limit over the entire optimization procedure.
- `gap_limit`:
    the desired relative optimality gap. Only used when `two_phase_gap=true`.
- `two_phase_gap`:
    if true, solve the problem with large gap tolerance first, then reduce
    the gap tolerance when no further violated constraints are found.
- `max_violations_per_branch`:
    maximum number of violated transmission constraints to add to the
    formulation per transmission branch.
- `max_violations_per_period`:
    maximum number of violated transmission constraints to add to the
    formulation per time period.
- `verbose`:
    if true, print detailed progress information during optimization.

"""
mutable struct Method <: SolutionMethod
    time_limit::Float64
    gap_limit::Float64
    two_phase_gap::Bool
    max_violations_per_branch::Int
    max_violations_per_period::Int
    verbose::Bool

    function Method(;
        time_limit::Float64 = 86400.0,
        gap_limit::Float64 = 1e-3,
        two_phase_gap::Bool = true,
        max_violations_per_branch::Int = 1,
        max_violations_per_period::Int = 5,
        verbose::Bool = false,
    )
        return new(
            time_limit,
            gap_limit,
            two_phase_gap,
            max_violations_per_branch,
            max_violations_per_period,
            verbose,
        )
    end
end
end

import DataStructures: PriorityQueue

struct _Violation
    time::Int
    monitored_branch::Branch
    outage_branch::Union{Branch,Nothing}
    amount::Float64

    function _Violation(;
        time::Int,
        monitored_branch::Branch,
        outage_branch::Union{Branch,Nothing},
        amount::Float64,
    )
        return new(time, monitored_branch, outage_branch, amount)
    end
end

mutable struct _ViolationFilter
    max_per_branch::Int
    max_total::Int
    queues::Dict{Int,PriorityQueue{_Violation,Float64}}

    function _ViolationFilter(; max_per_branch::Int = 1, max_total::Int = 5)
        return new(max_per_branch, max_total, Dict())
    end
end
