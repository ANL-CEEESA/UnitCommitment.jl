# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

function _add_startup_cost_eqs!(
    model::JuMP.Model,
    g::Unit,
    formulation::MorLatRam2013.StartupCosts,
)::Nothing
    eq_startup_choose = _init(model, :eq_startup_choose)
    eq_startup_restrict = _init(model, :eq_startup_restrict)
    S = length(g.startup_categories)
    startup = model[:startup]
    for t in 1:model[:instance].time
        for s in 1:S
            # If unit is switching on, we must choose a startup category
            eq_startup_choose[g.name, t, s] = @constraint(
                model,
                model[:switch_on][g.name, t] ==
                sum(startup[g.name, t, s] for s in 1:S)
            )

            # If unit has not switched off in the last `delay` time periods, startup category is forbidden.
            # The last startup category is always allowed.
            if s < S
                range_start = t - g.startup_categories[s+1].delay + 1
                range_end = t - g.startup_categories[s].delay
                range = (range_start:range_end)
                initial_sum = (
                    g.initial_status < 0 && (g.initial_status + 1 in range) ? 1.0 : 0.0
                )
                eq_startup_restrict[g.name, t, s] = @constraint(
                    model,
                    startup[g.name, t, s] <=
                    initial_sum + sum(
                        model[:switch_off][g.name, i] for i in range if i >= 1
                    )
                )
            end

            # Objective function terms for start-up costs
            add_to_expression!(
                model[:obj],
                startup[g.name, t, s],
                g.startup_categories[s].cost,
            )
        end
    end
    return
end
