# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

import Base.Threads: @threads, maxthreadid, threadid

"""
    _compute_line_flows(; net_injections, isf, lodf, contingencies)

Compute pre- and post-contingency line flows using ISF/LODF matrices.
Uses multi-threaded computation over time periods.

Returns `(pre_flow, post_flow)` where:
- `pre_flow` is an L × T matrix of base case flows
- `post_flow` is a Dict mapping outage line offset to L × T matrix of post-contingency flows
"""
function _compute_line_flows(;
    net_injections::Array{Float64,2},
    isf::Array{Float64,2},
    lodf::Array{Float64,2},
    contingencies::Vector{Contingency},
)
    L = size(isf, 1)
    T = size(net_injections, 2)
    vulnerable = Set{Int}()
    for c in contingencies, lc in c.lines
        push!(vulnerable, lc.offset)
    end

    # Pre-allocate all arrays with fixed dimensions
    pre_flow::Array{Float64} = zeros(L, T)
    post_flow =
        Dict{Int,Array{Float64,2}}(lc => zeros(L, T) for lc in vulnerable)

    @threads for t in 1:T
        # Use @view to avoid allocating a copy of the column.
        pre_flow[:, t] = isf * @view(net_injections[:, t])
        for lc in vulnerable
            for lm in 1:L
                post_flow[lc][lm, t] =
                    pre_flow[lm, t] + pre_flow[lc, t] * lodf[lm, lc]
            end
        end
    end

    return pre_flow, post_flow
end

function store_solution(
    sol::AbstractDict,
    model::JuMP.Model,
    ::ShiftFactorsTransmissionExt,
)::Nothing
    instance = model[:instance]
    T = instance.time
    ni = model[:ni]

    for sc in instance.scenarios
        lines = sc[:lines]
        buses = sc[:bus]

        if length(sc[:lines]) > 0
            isf = sc[:isf]
            lodf = sc[:lodf]
            non_slack = [b for b in buses if b.offset > 0]
            net_inj =
                [value(ni[sc.name, b.name, t]) for b in non_slack, t in 1:T]
            pre_flow, post_flow = _compute_line_flows(
                net_injections = net_inj,
                isf = isf,
                lodf = lodf,
                contingencies = sc[:contingencies],
            )
        end

        # Base case results
        sol[sc.name]["Line: Base Flow (MW)"] = OrderedDict(
            l.name =>
                [round(pre_flow[l.offset, t], digits = 5) for t in 1:T] for
            l in lines
        )
        sol[sc.name]["Line: Base Overflow (MW)"] = OrderedDict(
            l.name => [
                round(
                    max(
                        0.0,
                        abs(pre_flow[l.offset, t]) - l.normal_flow_limit[t],
                    ),
                    digits = 5,
                ) for t in 1:T
            ] for l in lines
        )
        sol[sc.name]["Line: Base Overflow penalty (\$)"] = OrderedDict(
            l.name => [
                round(
                    max(
                        0.0,
                        abs(pre_flow[l.offset, t]) - l.normal_flow_limit[t],
                    ) * l.flow_limit_penalty[t],
                    digits = 5,
                ) for t in 1:T
            ] for l in lines
        )
        sol[sc.name]["Line: Base Utilization (%)"] = OrderedDict(
            l.name => [
                round(
                    100.0 * abs(pre_flow[l.offset, t]) / l.normal_flow_limit[t],
                    digits = 2,
                ) for t in 1:T
            ] for l in lines
        )

        # Contingency results
        cont_flow = OrderedDict{String,OrderedDict}()
        cont_overflow = OrderedDict{String,OrderedDict}()
        for cont in sc[:contingencies]
            pf = post_flow[only(cont.lines).offset]

            cont_flow[cont.name] = OrderedDict(
                l.name => [round(pf[l.offset, t], digits = 5) for t in 1:T]
                for l in lines
            )
            cont_overflow[cont.name] = OrderedDict(
                l.name => [
                    round(
                        max(
                            0.0,
                            abs(pf[l.offset, t]) - l.emergency_flow_limit[t],
                        ),
                        digits = 5,
                    ) for t in 1:T
                ] for l in lines
            )
        end
        sol[sc.name]["Line: Contingency Flow (MW)"] = cont_flow
        sol[sc.name]["Line: Contingency Overflow (MW)"] = cont_overflow
    end

    return
end
