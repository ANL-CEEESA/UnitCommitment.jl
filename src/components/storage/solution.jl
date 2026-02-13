# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

function store_solution(
    sol::AbstractDict,
    model::UnitCommitmentModel,
    ::StorageExt,
)::Nothing
    instance = model.instance
    inner = model.inner
    T = instance.time
    for sc in instance.scenarios
        storage_units = sc[:storage]

        sol[sc.name]["Storage: Level (MWh)"] =
            _timeseries(inner, :storage_level, storage_units, T, sc = sc)
        sol[sc.name]["Storage: Is charging"] =
            _timeseries(inner, :is_charging, storage_units, T, sc = sc)
        sol[sc.name]["Storage: Charging rate (MW)"] =
            _timeseries(inner, :charge_rate, storage_units, T, sc = sc)
        sol[sc.name]["Storage: Charging cost (\$)"] = OrderedDict(
            su.name => [
                value(inner[:charge_rate][sc.name, su.name, t]) *
                su.charge_cost[t] for t in 1:T
            ] for su in storage_units
        )
        sol[sc.name]["Storage: Is discharging"] =
            _timeseries(inner, :is_discharging, storage_units, T, sc = sc)
        sol[sc.name]["Storage: Discharging rate (MW)"] =
            _timeseries(inner, :discharge_rate, storage_units, T, sc = sc)
        sol[sc.name]["Storage: Discharging cost (\$)"] = OrderedDict(
            su.name => [
                value(inner[:discharge_rate][sc.name, su.name, t]) *
                su.discharge_cost[t] for t in 1:T
            ] for su in storage_units
        )
        sol[sc.name]["Storage: Investment status"] = OrderedDict(
            su.name =>
                [value(inner[:invest_storage][su.name, t]) for t in 1:T] for
            su in storage_units if su.invest[1] > 0.0
        )
        sol[sc.name]["Storage: Reactive power (MVAr)"] =
            _timeseries(inner, :qs, storage_units, T, sc = sc)
    end

    return
end
