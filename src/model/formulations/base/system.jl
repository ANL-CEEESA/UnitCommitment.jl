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

function _add_system_wide_eqs!(
    model::JuMP.Model,
    ::PhaseAngleFormulation,
    sc::UnitCommitmentScenario,
)::Nothing
    _add_nodal_balance!(model, sc)
    return
end

function _add_nodal_balance!(
    model::JuMP.Model,
    sc::UnitCommitmentScenario,
)::Nothing
    # Nodal balance for phase angle formulation
    eq_nodal_balance = _init(model, :eq_nodal_balance)
    for t in 1:model[:instance].time
        for b in sc.buses
            eq_nodal_balance[sc.name, b.name, t] = @constraint(
                model,
                sum(
                    model[:flow][sc.name, lm.name, t] for
                    lm in sc.data[:lines] if lm.source == b
                ) - sum(
                    model[:flow][sc.name, lm.name, t] for
                    lm in sc.data[:lines] if lm.target == b
                ) + model[:net_injection][sc.name, b.name, t] == 0
            )
        end
    end
    return
end
