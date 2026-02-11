# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

function store_solution(
    sol::AbstractDict,
    model::JuMP.Model,
    ::PhaseAngleTransmissionExt,
)::Nothing
    instance = model[:instance]
    T = instance.time

    for sc in instance.scenarios
        lines = sc[:lines]
        flows = _timeseries(model, :flow, lines, T, sc = sc)
        sol[sc.name]["Line: Base Flow (MW)"] = OrderedDict(
            line.name =>
                [round(flows[line.name][t], digits = 5) for t in 1:T] for
            line in lines
        )
        sol[sc.name]["Line: Base Overflow (MW)"] =
            _timeseries(model, :overflow, lines, T, sc = sc)
        sol[sc.name]["Line: Base Overflow penalty (\$)"] = OrderedDict(
            line.name => [
                value(model[:overflow][sc.name, line.name, t]) *
                line.flow_limit_penalty[t] for t in 1:T
            ] for line in lines
        )
        sol[sc.name]["Line: Base Utilization (%)"] = OrderedDict(
            line.name => [
                round(
                    100.0 * abs(flows[line.name][t]) /
                    line.normal_flow_limit[t],
                    digits = 2,
                ) for t in 1:T
            ] for line in lines
        )
        sol[sc.name]["Line: Investment cost (\$)"] = OrderedDict(
            line.name => [
                (
                    value(model[:invest][line.name, t]) -
                    value(model[:invest][line.name, t-1])
                ) * line.invest[t] for t in 1:T
            ] for line in lines if line.invest[1] > 0.0
        )
        sol[sc.name]["Line: Investment status"] = OrderedDict(
            line.name => [value(model[:invest][line.name, t]) for t in 1:T]
            for line in lines if line.invest[1] > 0.0
        )
    end

    return
end
