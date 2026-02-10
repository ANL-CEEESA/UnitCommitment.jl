# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

function _add_system_wide_eqs!(
    model::JuMP.Model,
    ::ShiftFactorsFormulation,
    sc::UnitCommitmentScenario,
)::Nothing
    _add_spinning_reserve_eqs!(model, sc)
    return
end
