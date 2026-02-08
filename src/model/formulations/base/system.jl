# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

function _add_system_wide_eqs!(
    model::JuMP.Model,
    ::ShiftFactorsFormulation,
    sc::UnitCommitmentScenario,
)::Nothing
    _add_spinning_reserve_eqs!(model, sc)
    _add_flexiramp_reserve_eqs!(model, sc)
    return
end

function _add_system_wide_eqs!(
    model::JuMP.Model,
    ::PhaseAngleFormulation,
    sc::UnitCommitmentScenario,
)::Nothing
    _add_nodal_balance!(model, sc)
    _add_flexiramp_reserve_eqs!(model, sc)
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
                    lm in sc.lines if lm.source == b
                ) - sum(
                    model[:flow][sc.name, lm.name, t] for
                    lm in sc.lines if lm.target == b
                ) + model[:net_injection][sc.name, b.name, t] == 0
            )
        end
    end
    return
end

function _add_flexiramp_reserve_eqs!(
    model::JuMP.Model,
    sc::UnitCommitmentScenario,
)::Nothing
    # Note: The flexpramp requirements in Wang & Hobbs (2016) are imposed as hard constraints 
    #       through Eq. (17) and Eq. (18). The constraints eq_min_upflexiramp and eq_min_dwflexiramp 
    #       provided below are modified versions of Eq. (17) and Eq. (18), respectively, in that   
    #       they include slack variables for flexiramp shortfall, which are penalized in the
    #       objective function.
    eq_min_upflexiramp = _init(model, :eq_min_upflexiramp)
    eq_min_dwflexiramp = _init(model, :eq_min_dwflexiramp)
    T = model[:instance].time
    for r in sc.reserves
        r.type == "flexiramp" || continue
        for t in 1:T
            # Eq. (17) in Wang & Hobbs (2016)
            eq_min_upflexiramp[sc.name, r.name, t] = @constraint(
                model,
                sum(
                    model[:upflexiramp][sc.name, r.name, g.name, t] for
                    g in r.thermal_units
                ) + model[:upflexiramp_shortfall][sc.name, r.name, t] >=
                r.amount[t]
            )
            # Eq. (18) in Wang & Hobbs (2016)
            eq_min_dwflexiramp[sc.name, r.name, t] = @constraint(
                model,
                sum(
                    model[:dwflexiramp][sc.name, r.name, g.name, t] for
                    g in r.thermal_units
                ) + model[:dwflexiramp_shortfall][sc.name, r.name, t] >=
                r.amount[t]
            )

            # Account for flexiramp shortfall contribution to objective
            if r.shortfall_penalty >= 0
                add_to_expression!(
                    model[:obj],
                    r.shortfall_penalty * sc.probability,
                    (
                        model[:upflexiramp_shortfall][sc.name, r.name, t] +
                        model[:dwflexiramp_shortfall][sc.name, r.name, t]
                    ),
                )
            end
        end
    end
    return
end
