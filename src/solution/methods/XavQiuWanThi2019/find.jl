# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

import Base.Threads: @threads

function _find_violations(model::JuMP.Model; max_per_line::Int, max_per_period::Int)
    instance = model[:instance]
    net_injection = model[:net_injection]
    overflow = model[:overflow]
    length(instance.buses) > 1 || return []
    violations = []
    @info "Verifying transmission limits..."
    time_screening = @elapsed begin
        non_slack_buses = [b for b in instance.buses if b.offset > 0]
        net_injection_values = [
            value(net_injection[b.name, t]) for b in non_slack_buses, t = 1:instance.time
        ]
        overflow_values =
            [value(overflow[lm.name, t]) for lm in instance.lines, t = 1:instance.time]
        violations = UnitCommitment._find_violations(
            instance = instance,
            net_injections = net_injection_values,
            overflow = overflow_values,
            isf = model[:isf],
            lodf = model[:lodf],
            max_per_line = max_per_line,
            max_per_period = max_per_period,
        )
    end
    @info @sprintf("Verified transmission limits in %.2f seconds", time_screening)
    return violations
end

"""
    function _find_violations(
        instance::UnitCommitmentInstance,
        net_injections::Array{Float64, 2};
        isf::Array{Float64,2},
        lodf::Array{Float64,2},
        max_per_line::Int,
        max_per_period::Int,
    )::Array{_Violation, 1}

Find transmission constraint violations (both pre-contingency, as well as
post-contingency).

The argument `net_injection` should be a (B-1) x T matrix, where B is the
number of buses and T is the number of time periods. The arguments `isf` and
`lodf` can be computed using UnitCommitment.injection_shift_factors and
UnitCommitment.line_outage_factors. The argument `overflow` specifies how much
flow above the transmission limits (in MW) is allowed. It should be an L x T
matrix, where L is the number of transmission lines.
"""
function _find_violations(;
    instance::UnitCommitmentInstance,
    net_injections::Array{Float64,2},
    overflow::Array{Float64,2},
    isf::Array{Float64,2},
    lodf::Array{Float64,2},
    max_per_line::Int,
    max_per_period::Int,
)::Array{_Violation,1}
    B = length(instance.buses) - 1
    L = length(instance.lines)
    T = instance.time
    K = nthreads()

    size(net_injections) == (B, T) || error("net_injections has incorrect size")
    size(isf) == (L, B) || error("isf has incorrect size")
    size(lodf) == (L, L) || error("lodf has incorrect size")

    filters = Dict(
        t => _ViolationFilter(max_total = max_per_period, max_per_line = max_per_line)
        for t = 1:T
    )

    pre_flow::Array{Float64} = zeros(L, K)           # pre_flow[lm, thread]
    post_flow::Array{Float64} = zeros(L, L, K)       # post_flow[lm, lc, thread]
    pre_v::Array{Float64} = zeros(L, K)              # pre_v[lm, thread]
    post_v::Array{Float64} = zeros(L, L, K)          # post_v[lm, lc, thread]

    normal_limits::Array{Float64,2} =
        [l.normal_flow_limit[t] + overflow[l.offset, t] for l in instance.lines, t = 1:T]

    emergency_limits::Array{Float64,2} =
        [l.emergency_flow_limit[t] + overflow[l.offset, t] for l in instance.lines, t = 1:T]

    is_vulnerable::Array{Bool} = zeros(Bool, L)
    for c in instance.contingencies
        is_vulnerable[c.lines[1].offset] = true
    end

    @threads for t = 1:T
        k = threadid()

        # Pre-contingency flows
        pre_flow[:, k] = isf * net_injections[:, t]

        # Post-contingency flows
        for lc = 1:L, lm = 1:L
            post_flow[lm, lc, k] = pre_flow[lm, k] + pre_flow[lc, k] * lodf[lm, lc]
        end

        # Pre-contingency violations
        for lm = 1:L
            pre_v[lm, k] = max(
                0.0,
                pre_flow[lm, k] - normal_limits[lm, t],
                -pre_flow[lm, k] - normal_limits[lm, t],
            )
        end

        # Post-contingency violations
        for lc = 1:L, lm = 1:L
            post_v[lm, lc, k] = max(
                0.0,
                post_flow[lm, lc, k] - emergency_limits[lm, t],
                -post_flow[lm, lc, k] - emergency_limits[lm, t],
            )
        end

        # Offer pre-contingency violations
        for lm = 1:L
            if pre_v[lm, k] > 1e-5
                _offer(
                    filters[t],
                    _Violation(
                        time = t,
                        monitored_line = instance.lines[lm],
                        outage_line = nothing,
                        amount = pre_v[lm, k],
                    ),
                )
            end
        end

        # Offer post-contingency violations
        for lm = 1:L, lc = 1:L
            if post_v[lm, lc, k] > 1e-5 && is_vulnerable[lc]
                _offer(
                    filters[t],
                    _Violation(
                        time = t,
                        monitored_line = instance.lines[lm],
                        outage_line = instance.lines[lc],
                        amount = post_v[lm, lc, k],
                    ),
                )
            end
        end
    end

    violations = _Violation[]
    for t = 1:instance.time
        append!(violations, _query(filters[t]))
    end

    return violations
end
