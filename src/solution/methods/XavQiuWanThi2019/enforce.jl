# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

function _enforce_transmission(
    model::JuMP.Model,
    violations::Vector{_Violation},
    sc::UnitCommitmentScenario,
)::Nothing
    for v in violations
        _enforce_transmission(
            model = model,
            sc = sc,
            violation = v,
            isf = sc.isf,
            lodf = sc.lodf,
        )
    end
    return
end

function _enforce_transmission(;
    model::JuMP.Model,
    sc::UnitCommitmentScenario,
    violation::_Violation,
    isf::Matrix{Float64},
    lodf::Matrix{Float64},
)::Nothing
    instance = model[:instance]
    limit::Float64 = 0.0
    overflow = model[:overflow]
    net_injection = model[:net_injection]

    if violation.outage_line === nothing
        limit = violation.monitored_line.normal_flow_limit[violation.time]
        @info @sprintf(
            "    %8.3f MW overflow in %-5s time %3d (pre-contingency, scenario %s)",
            violation.amount,
            violation.monitored_line.name,
            violation.time,
            sc.name,
        )
    else
        limit = violation.monitored_line.emergency_flow_limit[violation.time]
        @info @sprintf(
            "    %8.3f MW overflow in %-5s time %3d (outage: line %s, scenario %s)",
            violation.amount,
            violation.monitored_line.name,
            violation.time,
            violation.outage_line.name,
            sc.name,
        )
    end

    fm = violation.monitored_line.name
    t = violation.time
    flow = @variable(model, base_name = "flow[$fm,$t]")

    v = overflow[sc.name, violation.monitored_line.name, violation.time]
    @constraint(model, flow <= limit + v)
    @constraint(model, -flow <= limit + v)

    if violation.outage_line === nothing
        @constraint(
            model,
            flow == sum(
                net_injection[sc.name, b.name, violation.time] *
                isf[violation.monitored_line.offset, b.offset] for
                b in sc.buses if b.offset > 0
            )
        )
    else
        @constraint(
            model,
            flow == sum(
                net_injection[sc.name, b.name, violation.time] * (
                    isf[violation.monitored_line.offset, b.offset] + (
                        lodf[
                            violation.monitored_line.offset,
                            violation.outage_line.offset,
                        ] * isf[violation.outage_line.offset, b.offset]
                    )
                ) for b in sc.buses if b.offset > 0
            )
        )
    end
    return nothing
end
