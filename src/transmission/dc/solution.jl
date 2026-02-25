# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

function store_solution(
    sol::AbstractDict,
    model::UnitCommitmentModel,
    ext::DCTransmissionExt,
)::Nothing
    instance = model.instance
    inner = model.inner
    T = instance.time

    for sc in instance.scenarios
        branches = sc[:branches]
        pre_flow = _compute_base_flow(model, sc, ext)

        sol[sc.name]["Branch: Base flow (MW)"] = OrderedDict(
            l.name =>
                [round(pre_flow[l.offset, t], digits = 10) for t in 1:T] for
            l in branches
        )
        sol[sc.name]["Branch: Overflow (MW)"] =
            _timeseries(inner, :overflow, branches, T, sc = sc)
        sol[sc.name]["Branch: Overflow penalty (\$)"] = OrderedDict(
            l.name => [
                value(inner[:overflow][sc.name, l.name, t]) *
                l.flow_limit_penalty[t] for t in 1:T
            ] for l in branches
        )
        sol[sc.name]["Branch: Base utilization (%)"] = OrderedDict(
            l.name => [
                round(
                    100.0 * abs(pre_flow[l.offset, t]) / l.normal_flow_limit[t],
                    digits = 2,
                ) for t in 1:T
            ] for l in branches
        )

        # Contingency results
        if !isempty(sc[:contingencies])
            post_flow = _compute_contingency_flow(model, sc, pre_flow, ext)
            cont_flows = OrderedDict{String,OrderedDict}()
            cont_overflow = OrderedDict{String,OrderedDict}()
            for cont in sc[:contingencies]
                outage_offset = only(cont.branches).offset
                cont_flows[cont.name] = OrderedDict(
                    l.name => [
                        round(
                            post_flow[outage_offset][l.offset, t],
                            digits = 10,
                        ) for t in 1:T
                    ] for l in branches
                )
                cont_overflow[cont.name] = OrderedDict(
                    l.name => [
                        round(
                            max(
                                0.0,
                                abs(post_flow[outage_offset][l.offset, t]) - l.emergency_flow_limit[t],
                            ),
                            digits = 10,
                        ) for t in 1:T
                    ] for l in branches
                )
            end
            sol[sc.name]["Branch: Contingency flow (MW)"] = cont_flows
            sol[sc.name]["Branch: Contingency overflow (MW)"] = cont_overflow
        end

        # Investment results
        invest_branches = [b for b in branches if b.invest[1] > 0.0]
        if !isempty(invest_branches)
            sol[sc.name]["Branch: Investment cost (\$)"] = OrderedDict(
                branch.name => [
                    (
                        value(inner[:invest][branch.name, t]) -
                        value(inner[:invest][branch.name, t-1])
                    ) * branch.invest[t] for t in 1:T
                ] for branch in invest_branches
            )
            sol[sc.name]["Branch: Investment status"] = OrderedDict(
                branch.name =>
                    [value(inner[:invest][branch.name, t]) for t in 1:T] for
                branch in invest_branches
            )
        end
    end

    return
end
