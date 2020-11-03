# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.
# Copyright (C) 2019 Argonne National Laboratory
# Written by Alinson Santos Xavier <axavier@anl.gov>


using DataStructures
using Base.Threads


struct Violation
    time::Int
    monitored_line::TransmissionLine
    outage_line::Union{TransmissionLine, Nothing}
    amount::Float64  # Violation amount (in MW)
end


function Violation(;
                   time::Int,
                   monitored_line::TransmissionLine,
                   outage_line::Union{TransmissionLine, Nothing},
                   amount::Float64,
                  ) :: Violation
    return Violation(time, monitored_line, outage_line, amount)
end


mutable struct ViolationFilter
    max_per_line::Int
    max_total::Int
    queues::Dict{Int, PriorityQueue{Violation, Float64}}
end


function ViolationFilter(;
                         max_per_line::Int=1,
                         max_total::Int=5,
                        )::ViolationFilter
    return ViolationFilter(max_per_line, max_total, Dict())
end


function offer(filter::ViolationFilter, v::Violation)::Nothing
    if v.monitored_line.offset ∉ keys(filter.queues)
        filter.queues[v.monitored_line.offset] = PriorityQueue{Violation, Float64}()
    end
    q::PriorityQueue{Violation, Float64} = filter.queues[v.monitored_line.offset]
    if length(q) < filter.max_per_line
        enqueue!(q, v => v.amount)
    else
        if v.amount > peek(q)[1].amount
            dequeue!(q)
            enqueue!(q, v => v.amount)
        end
    end
    nothing
end


function query(filter::ViolationFilter)::Array{Violation, 1}
    violations = Array{Violation,1}()
    time_queue = PriorityQueue{Violation, Float64}()
    for l in keys(filter.queues)
        line_queue = filter.queues[l]
        while length(line_queue) > 0
            v = dequeue!(line_queue)
            if length(time_queue) < filter.max_total
                enqueue!(time_queue, v => v.amount)
            else
                if v.amount > peek(time_queue)[1].amount
                    dequeue!(time_queue)
                    enqueue!(time_queue, v => v.amount)
                end
            end
        end
    end
    while length(time_queue) > 0
        violations = [violations; dequeue!(time_queue)]
    end
    return violations
end


"""

    function find_violations(instance::UnitCommitmentInstance,
                             net_injections::Array{Float64, 2};
                             isf::Array{Float64,2},
                             lodf::Array{Float64,2},
                             max_per_line::Int = 1,
                             max_per_period::Int = 5,
                            ) :: Array{Violation, 1}

Find transmission constraint violations (both pre-contingency, as well as post-contingency).

The argument `net_injection` should be a (B-1) x T matrix, where B is the number of buses
and T is the number of time periods. The arguments `isf` and `lodf` can be computed using
UnitCommitment.injection_shift_factors and UnitCommitment.line_outage_factors.
The argument `overflow` specifies how much flow above the transmission limits (in MW) is allowed.
It should be an L x T matrix, where L is the number of transmission lines.
"""
function find_violations(;
                         instance::UnitCommitmentInstance,
                         net_injections::Array{Float64, 2},
                         overflow::Array{Float64, 2},
                         isf::Array{Float64,2},
                         lodf::Array{Float64,2},
                         max_per_line::Int = 1,
                         max_per_period::Int = 5,
                        )::Array{Violation, 1}

    B = length(instance.buses) - 1
    L = length(instance.lines)
    T = instance.time
    K = nthreads()
    
    size(net_injections) == (B, T) || error("net_injections has incorrect size")
    size(isf) == (L, B) || error("isf has incorrect size")
    size(lodf) == (L, L) || error("lodf has incorrect size")
    
    filters = Dict(t => ViolationFilter(max_total=max_per_period,
                                        max_per_line=max_per_line)
                   for t in 1:T)
    
    pre_flow::Array{Float64} = zeros(L, K)           # pre_flow[lm, thread]
    post_flow::Array{Float64} = zeros(L, L, K)       # post_flow[lm, lc, thread]
    pre_v::Array{Float64} = zeros(L, K)              # pre_v[lm, thread]
    post_v::Array{Float64} = zeros(L, L, K)          # post_v[lm, lc, thread]
    
    normal_limits::Array{Float64,2} = [l.normal_flow_limit[t] + overflow[l.offset, t]
                                       for l in instance.lines, t in 1:T]
    
    emergency_limits::Array{Float64,2} = [l.emergency_flow_limit[t] + overflow[l.offset, t]
                                          for l in instance.lines, t in 1:T]
    
    is_vulnerable::Array{Bool} = zeros(Bool, L)
    for c in instance.contingencies
        is_vulnerable[c.lines[1].offset] = true
    end

    @threads for t in 1:T
        k = threadid()
        
        # Pre-contingency flows
        pre_flow[:, k] = isf * net_injections[:, t]
    
        # Post-contingency flows
        for lc in 1:L, lm in 1:L
            post_flow[lm, lc, k] = pre_flow[lm, k] + pre_flow[lc, k] * lodf[lm, lc]
        end
        
        # Pre-contingency violations
        for lm in 1:L
            pre_v[lm, k] = max(0.0,
                               pre_flow[lm, k] - normal_limits[lm, t],
                               - pre_flow[lm, k] - normal_limits[lm, t])
        end
        
        # Post-contingency violations
        for lc in 1:L, lm in 1:L
            post_v[lm, lc, k] = max(0.0,
                                    post_flow[lm, lc, k] - emergency_limits[lm, t],
                                    - post_flow[lm, lc, k] - emergency_limits[lm, t])
        end
        
        # Offer pre-contingency violations
        for lm in 1:L
            if pre_v[lm, k] > 1e-5
                offer(filters[t], Violation(time=t,
                                            monitored_line=instance.lines[lm],
                                            outage_line=nothing,
                                            amount=pre_v[lm, k]))
            end
        end
        
        # Offer post-contingency violations
        for lm in 1:L, lc in 1:L
            if post_v[lm, lc, k] > 1e-5 && is_vulnerable[lc]
                offer(filters[t], Violation(time=t,
                                            monitored_line=instance.lines[lm],
                                            outage_line=instance.lines[lc],
                                            amount=post_v[lm, lc, k]))
            end
        end
    end
    
    violations = Violation[]
    for t in 1:instance.time
        append!(violations, query(filters[t]))
    end
    
    return violations
end


export Violation, ViolationFilter, offer, query, find_violations