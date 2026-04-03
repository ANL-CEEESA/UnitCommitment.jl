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

        if haskey(inner, :theta)
            sol[sc.name]["Bus: Voltage angle (rad)"] = OrderedDict(
                b.name => [
                    round(
                        value(inner[:theta][sc.name, b.name, t]),
                        digits = 10,
                    ) for t in 1:T
                ] for b in sc[:bus]
            )
        end
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
            if length(sc[:bus]) < 100
                sol[sc.name]["Branch: Contingency flow (MW)"] = cont_flows
                sol[sc.name]["Branch: Contingency overflow (MW)"] =
                    cont_overflow
            end
        end

        # Investment results
        invest_branches = [b for b in branches if b.invest > 0.0]
        if !isempty(invest_branches)
            sol[sc.name]["Branch: Investment cost (\$)"] = OrderedDict(
                branch.name =>
                    value(inner[:invest][branch.name]) * branch.invest for
                branch in invest_branches
            )
            sol[sc.name]["Branch: Investment status"] = OrderedDict(
                branch.name => value(inner[:invest][branch.name]) for
                branch in invest_branches
            )
        end

        _store_transmission_summary!(sol[sc.name], sc, T)
    end

    return
end

function _store_transmission_summary!(sol::OrderedDict, sc, T::Int; ε = 1e-4)
    summary = sol["Summary"]

    overflow = sol["Branch: Overflow (MW)"]
    utilization = sol["Branch: Base utilization (%)"]
    overflow_penalty = sol["Branch: Overflow penalty (\$)"]

    # Branches with overflow
    summary["Branch: Branches with overflow"] =
        count(ts -> any(v > ε for v in ts), values(overflow))

    # Congested branches (utilization >= 100%)
    summary["Branch: Congested branches"] =
        count(ts -> any(v >= 100.0 for v in ts), values(utilization))

    # Peak total overflow
    overflow_per_t = _per_t(overflow, T)
    summary["Branch: Peak total overflow (MW)"] = maximum(overflow_per_t)

    # Total overflow penalty
    summary["Total penalty: Branch overflow (\$)"] = _total(overflow_penalty)

    # Investment
    if haskey(sol, "Branch: Investment cost (\$)")
        invest_cost = sol["Branch: Investment cost (\$)"]
        summary["Branch: Total investment cost (\$)"] = _total(invest_cost)
        if haskey(sol, "Branch: Investment status")
            invest_status = sol["Branch: Investment status"]
            summary["Branch: Circuits invested"] =
                count(ts -> ts[end] > 0.5, values(invest_status))
        end
    end
    return
end
