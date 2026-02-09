# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

function store_solution(
    sol::AbstractDict,
    model::JuMP.Model,
    ::StorageExt,
)::Nothing
    instance = model[:instance]
    T = instance.time
    for sc in instance.scenarios
        storage_units = sc.data[:storage]

        sol[sc.name]["Storage: Level (MWh)"] =
            _timeseries(model, :storage_level, storage_units, T, sc = sc)
        sol[sc.name]["Storage: Is charging"] =
            _timeseries(model, :is_charging, storage_units, T, sc = sc)
        sol[sc.name]["Storage: Charging rate (MW)"] =
            _timeseries(model, :charge_rate, storage_units, T, sc = sc)
        sol[sc.name]["Storage: Charging cost (\$)"] = OrderedDict(
            su.name => [
                value(model[:charge_rate][sc.name, su.name, t]) *
                su.charge_cost[t] for t in 1:T
            ] for su in storage_units
        )
        sol[sc.name]["Storage: Is discharging"] =
            _timeseries(model, :is_discharging, storage_units, T, sc = sc)
        sol[sc.name]["Storage: Discharging rate (MW)"] =
            _timeseries(model, :discharge_rate, storage_units, T, sc = sc)
        sol[sc.name]["Storage: Discharging cost (\$)"] = OrderedDict(
            su.name => [
                value(model[:discharge_rate][sc.name, su.name, t]) *
                su.discharge_cost[t] for t in 1:T
            ] for su in storage_units
        )
        sol[sc.name]["Storage: Investment status"] = OrderedDict(
            su.name =>
                [value(model[:invest_storage][su.name, t]) for t in 1:T] for
            su in storage_units if su.invest[1] > 0.0
        )
    end

    return
end
