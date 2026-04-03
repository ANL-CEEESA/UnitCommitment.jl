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
            su.name => value(inner[:invest_storage][su.name]) for
            su in storage_units if su.invest > 0.0
        )
        sol[sc.name]["Storage: Reactive power (MVAr)"] =
            _timeseries(inner, :qs, storage_units, T, sc = sc)

        _store_storage_summary!(sol[sc.name], sc, T)
    end

    return
end

function _store_storage_summary!(sol::OrderedDict, sc, T::Int)
    storage_units = sc[:storage]
    summary = sol["Summary"]

    charge_cost = sol["Storage: Charging cost (\$)"]
    discharge_cost = sol["Storage: Discharging cost (\$)"]
    charge = sol["Storage: Charging rate (MW)"]
    discharge = sol["Storage: Discharging rate (MW)"]
    level = sol["Storage: Level (MWh)"]

    dt = sc[:time_step] / 60  # minutes → hours

    # Total cost
    summary["Storage: Total cost (\$)"] =
        _total(charge_cost) + _total(discharge_cost)

    # Energy totals (MW × dt → MWh)
    charge_per_t = _per_t(charge, T)
    discharge_per_t = _per_t(discharge, T)

    total_charged = sum(charge_per_t) * dt
    total_discharged = sum(discharge_per_t) * dt
    summary["Storage: Total energy charged (MWh)"] = total_charged
    summary["Storage: Total energy discharged (MWh)"] = total_discharged

    # Round-trip loss = charged - discharged - Δ(stored)
    initial_level = sum(su.initial_level for su in storage_units; init = 0)
    final_level = sum(level[su.name][T] for su in storage_units; init = 0)
    delta_stored = final_level - initial_level
    summary["Storage: Round-trip loss (MWh)"] =
        total_charged - total_discharged - delta_stored

    # Peak rates
    summary["Storage: Peak charging rate (MW)"] = maximum(charge_per_t)
    summary["Storage: Peak discharging rate (MW)"] = maximum(discharge_per_t)

    # Investment
    if haskey(sol, "Storage: Investment status")
        invest_status = sol["Storage: Investment status"]
        invest_units = [su for su in storage_units if su.invest > 0.0]
        if !isempty(invest_units)
            summary["Storage: Total investment cost (\$)"] =
                sum(invest_status[su.name] * su.invest for su in invest_units)
            summary["Storage: Units invested"] =
                count(su -> invest_status[su.name] > 0.5, invest_units)
        end
    end
    return
end
