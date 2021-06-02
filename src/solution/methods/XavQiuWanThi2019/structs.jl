# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

"""
Lazy constraint solution method described in:

    Xavier, A. S., Qiu, F., Wang, F., & Thimmapuram, P. R. (2019). Transmission
    constraint filtering in large-scale security-constrained unit commitment. 
    IEEE Transactions on Power Systems, 34(3), 2457-2460.
    DOI: https://doi.org/10.1109/TPWRS.2019.2892620
"""
module XavQiuWanThi2019
import ..SolutionMethod
"""
    struct Method
        time_limit::Float64
        gap_limit::Float64
        two_phase_gap::Bool
        max_violations_per_line::Int
        max_violations_per_period::Int
    end

Fields
------

- `time_limit`:
    the time limit over the entire optimization procedure.
- `gap_limit`: 
    the desired relative optimality gap.
- `two_phase_gap`: 
    if true, solve the problem with large gap tolerance first, then reduce
    the gap tolerance when no further violated constraints are found.
- `max_violations_per_line`:
    maximum number of violated transmission constraints to add to the
    formulation per transmission line.
- `max_violations_per_period`:
    maximum number of violated transmission constraints to add to the
    formulation per time period.

"""
struct Method <: SolutionMethod
    time_limit::Float64
    gap_limit::Float64
    two_phase_gap::Bool
    max_violations_per_line::Int
    max_violations_per_period::Int

    function Method(;
        time_limit::Float64 = 86400.0,
        gap_limit::Float64 = 1e-3,
        two_phase_gap::Bool = true,
        max_violations_per_line::Int = 1,
        max_violations_per_period::Int = 5,
    )
        return new(
            time_limit,
            gap_limit,
            two_phase_gap,
            max_violations_per_line,
            max_violations_per_period,
        )
    end
end
end

import DataStructures: PriorityQueue

struct _Violation
    time::Int
    monitored_line::TransmissionLine
    outage_line::Union{TransmissionLine,Nothing}
    amount::Float64

    function _Violation(;
        time::Int,
        monitored_line::TransmissionLine,
        outage_line::Union{TransmissionLine,Nothing},
        amount::Float64,
    )
        return new(time, monitored_line, outage_line, amount)
    end
end

mutable struct _ViolationFilter
    max_per_line::Int
    max_total::Int
    queues::Dict{Int,PriorityQueue{_Violation,Float64}}

    function _ViolationFilter(; max_per_line::Int = 1, max_total::Int = 5)
        return new(max_per_line, max_total, Dict())
    end
end
