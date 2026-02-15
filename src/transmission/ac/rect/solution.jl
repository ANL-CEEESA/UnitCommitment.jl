# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

function _store_ac_voltage_solution!(
    sol::AbstractDict,
    model::JuMP.Model,
    sc,
    buses,
    T::Int,
    ::ACRectangular,
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
