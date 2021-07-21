# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

"""
    _add_production_vars!(model, unit, formulation_prod_vars)

Creates variables `:prod_above` and `:segprod`.
"""
function _add_production_vars!(
    model::JuMP.Model,
    g::Unit,
    formulation_prod_vars::Gar1962.ProdVars,
)::Nothing
    prod_above = _init(model, :prod_above)
    segprod = _init(model, :segprod)
    for t in 1:model[:instance].time
        for k in 1:length(g.cost_segments)
            segprod[g.name, t, k] = @variable(model, lower_bound = 0)
        end
        prod_above[g.name, t] = @variable(model, lower_bound = 0)
    end
    return
end

"""
    _add_production_limit_eqs!(model, unit, formulation_prod_vars)

Ensure production limit constraints are met.
Based on Garver (1962) and Morales-España et al. (2013).
Eqns. (18), part of (69) in Kneuven et al. (2020).

===
Variables
* :is_on
* :prod_above
* :reserve

===
Constraints
* :eq_prod_limit
"""
function _add_production_limit_eqs!(
    model::JuMP.Model,
    g::Unit,
    formulation_prod_vars::Gar1962.ProdVars,
)::Nothing
    eq_prod_limit = _init(model, :eq_prod_limit)
    is_on = model[:is_on]
    prod_above = model[:prod_above]
    reserve = model[:reserve]
    gn = g.name
    for t in 1:model[:instance].time
        # Objective function terms for production costs
        # Part of (69) of Kneuven et al. (2020) as C^R_g * u_g(t) term
        add_to_expression!(model[:obj], is_on[gn, t], g.min_power_cost[t])

        # Production limit
        # Equation (18) in Kneuven et al. (2020)
        #   as \bar{p}_g(t) \le \bar{P}_g u_g(t)
        # amk: this is a weaker version of (20) and (21) in Kneuven et al. (2020)
        #      but keeping it here in case those are not present
        power_diff = max(g.max_power[t], 0.0) - max(g.min_power[t], 0.0)
        if power_diff < 1e-7
            power_diff = 0.0
        end
        eq_prod_limit[gn, t] = @constraint(
            model,
            prod_above[gn, t] + reserve[gn, t] <= power_diff * is_on[gn, t]
        )
    end
end
