# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

function _store_ac_voltage_solution!(
    sol::AbstractDict,
    model::JuMP.Model,
    sc,
    buses,
    T::Int,
    ::ACPolar,
)::Nothing
    sol[sc.name]["Bus: Voltage magnitude (p.u.)"] =
        _timeseries(model, :vm, buses, T, sc = sc, digits = 10)
    sol[sc.name]["Bus: Voltage angle (rad)"] =
        _timeseries(model, :va, buses, T, sc = sc, digits = 10)
    return
end
