# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

function store_solution(
    sol::AbstractDict,
    model::UnitCommitmentModel,
    ext::ACTransmissionExt,
)::Nothing
    instance = model.instance
    inner = model.inner
    T = instance.time

    for sc in instance.scenarios
        branches = sc[:ac_branches]
        buses = sc[:bus]

        # Shared extraction (formulation-agnostic flow variables)
        sol[sc.name]["Line: Base Flow (MW)"] =
            _timeseries(inner, :pf, branches, T, sc = sc, digits = 10)
        sol[sc.name]["Line: Reactive flow (MVAr)"] =
            _timeseries(inner, :qf, branches, T, sc = sc, digits = 10)
        sol[sc.name]["Line: Base Overflow (MW)"] =
            _timeseries(inner, :overflow, branches, T, sc = sc)
        sol[sc.name]["Line: Base Overflow penalty (\$)"] = OrderedDict(
            l.name => [
                value(inner[:overflow][sc.name, l.name, t]) *
                l.flow_limit_penalty[t] for t in 1:T
            ] for l in branches
        )
        sol[sc.name]["Line: Base Utilization (%)"] = OrderedDict(
            l.name => [
                round(
                    100.0 * sqrt(
                        value(inner[:pf][sc.name, l.name, t])^2 +
                        value(inner[:qf][sc.name, l.name, t])^2,
                    ) / l.normal_flow_limit[t],
                    digits = 2,
                ) for t in 1:T
            ] for l in branches
        )

        # Dispatched voltage extraction (formulation-specific)
        _store_ac_voltage_solution!(sol, inner, sc, buses, T, ext.formulation)
    end

    return
end

function _store_ac_voltage_solution!(
    sol::AbstractDict,
    model::JuMP.Model,
    sc,
    buses,
    T::Int,
    ::ACR.Formulation,
)::Nothing
    vr = model[:vr]
    vi = model[:vi]

    sol[sc.name]["Bus: Voltage magnitude (p.u.)"] = OrderedDict(
        b.name => [
            round(
                sqrt(
                    value(vr[sc.name, b.name, t])^2 +
                    value(vi[sc.name, b.name, t])^2,
                ),
                digits = 10,
            ) for t in 1:T
        ] for b in buses
    )
    sol[sc.name]["Bus: Voltage angle (rad)"] = OrderedDict(
        b.name => [
            round(
                atan(
                    value(vi[sc.name, b.name, t]),
                    value(vr[sc.name, b.name, t]),
                ),
                digits = 10,
            ) for t in 1:T
        ] for b in buses
    )
    return
end

function _store_ac_voltage_solution!(
    sol::AbstractDict,
    model::JuMP.Model,
    sc,
    buses,
    T::Int,
    ::ACP.Formulation,
)::Nothing
    sol[sc.name]["Bus: Voltage magnitude (p.u.)"] =
        _timeseries(model, :vm, buses, T, sc = sc, digits = 10)
    sol[sc.name]["Bus: Voltage angle (rad)"] =
        _timeseries(model, :va, buses, T, sc = sc, digits = 10)
    return
end
