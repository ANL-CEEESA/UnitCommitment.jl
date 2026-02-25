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
        branches = sc[:branches]
        buses = sc[:bus]

        # Shared extraction (formulation-agnostic flow variables)
        sol[sc.name]["Branch: Base active flow from-end (MW)"] =
            _timeseries(inner, :pf, branches, T, sc = sc, digits = 10)
        sol[sc.name]["Branch: Base reactive flow from-end (MVAr)"] =
            _timeseries(inner, :qf, branches, T, sc = sc, digits = 10)
        sol[sc.name]["Branch: Base active flow to-end (MW)"] =
            _timeseries(inner, :pt, branches, T, sc = sc, digits = 10)
        sol[sc.name]["Branch: Base reactive flow to-end (MVAr)"] =
            _timeseries(inner, :qt, branches, T, sc = sc, digits = 10)
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
