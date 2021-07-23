# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

"""
    _add_system_wide_eqs!(model::JuMP.Model)::Nothing

Adds constraints that apply to the whole system, such as relating to net injection and reserves.
"""
function _add_system_wide_eqs!(model::JuMP.Model)::Nothing
    _add_net_injection_eqs!(model)
    _add_reserve_eqs!(model)
    return
end

"""
    _add_net_injection_eqs!(model::JuMP.Model)::Nothing

Adds `net_injection`, `eq_net_injection_def`, and `eq_power_balance` identifiers into `model`.

Variables
---
* `expr_net_injection`
* `net_injection`

Constraints
---
* `eq_net_injection_def`
* `eq_power_balance`
"""
function _add_net_injection_eqs!(model::JuMP.Model)::Nothing
    T = model[:instance].time
    net_injection = _init(model, :net_injection)
    eq_net_injection = _init(model, :eq_net_injection)
    eq_power_balance = _init(model, :eq_power_balance)
    for t in 1:T, b in model[:instance].buses
        n = net_injection[b.name, t] = @variable(model)
        eq_net_injection[b.name, t] =
            @constraint(model, -n + model[:expr_net_injection][b.name, t] == 0)
    end
    for t in 1:T
        eq_power_balance[t] = @constraint(
            model,
            sum(net_injection[b.name, t] for b in model[:instance].buses) == 0
        )
    end
    return
end

"""
    _add_reserve_eqs!(model::JuMP.Model)::Nothing

Ensure constraints on reserves are met.
Based on Morales-España et al. (2013a).
Eqn. (68) from Knueven et al. (2020).

Adds `eq_min_reserve` identifier to `model`, and corresponding constraint.

Variables
---
* `reserve`
* `reserve_shortfall`

Constraints
---
* `eq_min_reserve`
"""
function _add_reserve_eqs!(model::JuMP.Model)::Nothing
    instance = model[:instance]
    eq_min_reserve = _init(model, :eq_min_reserve)
    instance = model[:instance]
    for t in 1:instance.time
        # Equation (68) in Kneuven et al. (2020)
        # As in Morales-España et al. (2013a)
        # Akin to the alternative formulation with max_power_avail
        # from Carrión and Arroyo (2006) and Ostrowski et al. (2012)
        shortfall_penalty = instance.shortfall_penalty[t]
        eq_min_reserve[t] = @constraint(
            model,
            sum(model[:reserve][g.name, t] for g in instance.units) +
            (shortfall_penalty >= 0 ? model[:reserve_shortfall][t] : 0.0) >=
            instance.reserves.spinning[t]
        )

        # Account for shortfall contribution to objective
        if shortfall_penalty >= 0
            add_to_expression!(
                model[:obj],
                shortfall_penalty,
                model[:reserve_shortfall][t],
            )
        end
    end
    return
end
