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
    "Production (MW)" ∈ keys(solution) ? solution = Dict("s1" => solution) :
    nothing
    is_on = model[:is_on]
    prod_above = model[:prod_above]
    reserve = model[:reserve]
    for sc in instance.scenarios
        for g in sc.units
            for t in 1:T
                is_on_value = round(solution[sc.name]["Is on"][g.name][t])
                prod_value = round(
                    solution[sc.name]["Production (MW)"][g.name][t],
                    digits = 5,
                )
                JuMP.fix(is_on[g.name, t], is_on_value, force = true)
                JuMP.fix(
                    prod_above[sc.name, g.name, t],
                    prod_value - is_on_value * g.min_power[t],
                    force = true,
                )
            end
        end
        for r in sc.reserves
            r.type == "spinning" || continue
            for g in r.units
                for t in 1:T
                    reserve_value = round(
                        solution[sc.name]["Spinning reserve (MW)"][r.name][g.name][t],
                        digits = 5,
                    )
                    JuMP.fix(
                        reserve[sc.name, r.name, g.name, t],
                        reserve_value,
                        force = true,
                    )
                end
            end
        end
    end
    return
end
