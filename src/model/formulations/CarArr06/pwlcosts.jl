# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

function _add_production_piecewise_linear_eqs!(
    model::JuMP.Model,
    g::Unit,
    formulation::CarArr06,
)::Nothing
    eq_prod_above_def = _init(model, :eq_prod_above_def)
    eq_segprod_limit = _init(model, :eq_segprod_limit)
    prod_above = model[:prod_above]
    segprod = model[:segprod]
    gn = g.name
    K = length(g.cost_segments)
    for t in 1:model[:instance].time
        gn = g.name
        for k in 1:K
            # Equation (45) in Kneuven et al. (2020)
            # NB: when reading instance, UnitCommitment.jl already calculates
            #     difference between max power for segments k and k-1 so the
            #     value of cost_segments[k].mw[t] is the max production *for
            #     that segment*
            eq_segprod_limit[gn, t, k] = @constraint(
                model,
                segprod[gn, t, k] <= g.cost_segments[k].mw[t]
            )

            # Also add this as an explicit upper bound on segprod to make the
            # solver's work a bit easier
            set_upper_bound(segprod[gn, t, k], g.cost_segments[k].mw[t])

            # Definition of production
            # Equation (43) in Kneuven et al. (2020)
            eq_prod_above_def[gn, t] = @constraint(
                model,
                prod_above[gn, t] == sum(segprod[gn, t, k] for k in 1:K)
            )

            # Objective function
            # Equation (44) in Kneuven et al. (2020)
            add_to_expression!(
                model[:obj],
                segprod[gn, t, k],
                g.cost_segments[k].cost[t],
            )
        end
    end
end
