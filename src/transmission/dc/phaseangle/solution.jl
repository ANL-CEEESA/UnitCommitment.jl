# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

function store_solution(
    sol::AbstractDict,
    model::UnitCommitmentModel,
    ::PhaseAngleTransmissionExt,
)::Nothing
    instance = model.instance
    inner = model.inner
    T = instance.time

    for sc in instance.scenarios
        branches = sc[:branches]
        flows = _timeseries(inner, :flow, branches, T, sc = sc)
        sol[sc.name]["Branch: Base flow (MW)"] = OrderedDict(
            branch.name =>
                [round(flows[branch.name][t], digits = 10) for t in 1:T] for
            branch in branches
        )
        sol[sc.name]["Branch: Base overflow (MW)"] =
            _timeseries(inner, :overflow, branches, T, sc = sc)
        sol[sc.name]["Branch: Base overflow penalty (\$)"] = OrderedDict(
            branch.name => [
                value(inner[:overflow][sc.name, branch.name, t]) *
                branch.flow_limit_penalty[t] for t in 1:T
            ] for branch in branches
        )
        sol[sc.name]["Branch: Base utilization (%)"] = OrderedDict(
            branch.name => [
                round(
                    100.0 * abs(flows[branch.name][t]) /
                    branch.normal_flow_limit[t],
                    digits = 2,
                ) for t in 1:T
            ] for branch in branches
        )
        sol[sc.name]["Branch: Investment cost (\$)"] = OrderedDict(
            branch.name => [
                (
                    value(inner[:invest][branch.name, t]) -
                    value(inner[:invest][branch.name, t-1])
                ) * branch.invest[t] for t in 1:T
            ] for branch in branches if branch.invest[1] > 0.0
        )
        sol[sc.name]["Branch: Investment status"] = OrderedDict(
            branch.name =>
                [value(inner[:invest][branch.name, t]) for t in 1:T] for
            branch in branches if branch.invest[1] > 0.0
        )
    end

    return
end
