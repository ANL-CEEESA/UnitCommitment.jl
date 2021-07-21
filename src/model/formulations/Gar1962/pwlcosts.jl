# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

"""
    _add_production_piecewise_linear_eqs!

Ensure respect of production limits along each segment.
Based on Garver (1962).
Equations (42), (43), (44) in Kneuven et al. (2020).
NB: when reading instance, UnitCommitment.jl already calculates difference between max power for segments k and k-1,
so the value of cost_segments[k].mw[t] is the max production *for that segment*.

Added to `model`: `:eq_prod_above_def` and `:eq_segprod_limit`.

===
Variables
* :segprod
* :is_on
* :prod_above

===
Constraints
* :eq_prod_above_def
* :eq_segprod_limit
"""
function _add_production_piecewise_linear_eqs!(
    model::JuMP.Model,
    g::Unit,
    formulation_prod_vars::Gar1962.ProdVars,
    formulation_pwl_costs::Gar1962.PwlCosts,
    formulation_status_vars::Gar1962.StatusVars,
)::Nothing
    eq_prod_above_def = _init(model, :eq_prod_above_def)
    eq_segprod_limit = _init(model, :eq_segprod_limit)
    segprod = model[:segprod]
    gn = g.name

    # Gar1962.ProdVars
    prod_above = model[:prod_above]

    # Gar1962.StatusVars
    is_on = model[:is_on]

    K = length(g.cost_segments)
    for t in 1:model[:instance].time
        # Definition of production
        # Equation (43) in Kneuven et al. (2020)
        eq_prod_above_def[gn, t] = @constraint(
            model,
            prod_above[gn, t] == sum(segprod[gn, t, k] for k in 1:K)
        )

        for k in 1:K
            # Equation (42) in Kneuven et al. (2020)
            # Without this, solvers will add a lot of implied bound cuts to
            # have this same effect.
            # NB: when reading instance, UnitCommitment.jl already calculates
            #     difference between max power for segments k and k-1 so the
            #     value of cost_segments[k].mw[t] is the max production *for
            #     that segment*
            eq_segprod_limit[gn, t, k] = @constraint(
                model,
                segprod[gn, t, k] <= g.cost_segments[k].mw[t] * is_on[gn, t]
            )

            # Also add this as an explicit upper bound on segprod to make the
            # solver's work a bit easier
            set_upper_bound(segprod[gn, t, k], g.cost_segments[k].mw[t])

            # Objective function
            # Equation (44) in Kneuven et al. (2020)
            add_to_expression!(
                model[:obj],
                segprod[gn, t, k],
                g.cost_segments[k].cost[t],
            )
        end
    end
    return
end
