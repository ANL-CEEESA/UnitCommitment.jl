# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

function _store_bus_solution!(sol::OrderedDict, model::JuMP.Model, sc, T::Int)
    sol["Bus: Net injection (MW)"] =
        _timeseries(model, :net_injection, sc[:bus], T, sc = sc)
    sol["Bus: Load curtail (MW)"] =
        _timeseries(model, :curtail, sc[:bus], T, sc = sc)
    return
end
