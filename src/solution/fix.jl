# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

"""
    fix!(model::JuMP.Model, solution::AbstractDict)::Nothing

Fix the value of all binary variables to the ones specified by the given
solution. Useful for computing LMPs.
"""
function fix!(model::JuMP.Model, solution::AbstractDict)::Nothing
    instance, T = model[:instance], model[:instance].time
    is_on = model[:is_on]
    prod_above = model[:prod_above]
    reserve = model[:reserve]
    for g in instance.units
        for t in 1:T
            is_on_value = round(solution["Is on"][g.name][t])
            prod_value =
                round(solution["Production (MW)"][g.name][t], digits = 5)
            JuMP.fix(is_on[g.name, t], is_on_value, force = true)
            JuMP.fix(
                prod_above[g.name, t],
                prod_value - is_on_value * g.min_power[t],
                force = true,
            )
        end
    end
    for r in instance.reserves
        for g in r.units
            for t in 1:T
                reserve_value = round(
                    solution["Reserve (MW)"][r.name][g.name][t],
                    digits = 5,
                )
                JuMP.fix(
                    reserve[r.name, g.name, t],
                    reserve_value,
                    force = true,
                )
            end
        end
    end
    return
end
