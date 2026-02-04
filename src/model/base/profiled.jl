# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

function _add_profiled_units!(
    model::JuMP.Model,
    instance::UnitCommitmentInstance,
)::Nothing
    _add_profiled_vars!(model, instance)
    _add_profiled_obj!(model, instance)
    _add_profiled_constr_invest!(model, instance)
    return
end

function _add_profiled_vars!(
    model::JuMP.Model,
    instance::UnitCommitmentInstance,
)::Nothing
    T = instance.time
    prod = _init(model, :prod)
    invest = _init(model, :invest)

    # Production
    for sc in instance.scenarios, pu in sc.profiled_units
        for t in 1:T
            prod[sc.name, pu.name, t] = @variable(
                model,
                lower_bound = pu.min_power[t],
                upper_bound = pu.max_power[t],
            )
            # add_to_expression!(
            #     model[:net_injection][sc.name, pu.bus.name, t],
            #     prod[sc.name, pu.name, t],
            #     1.0,
            # )
        end
    end

    # Investment
    for pu in instance.scenarios[1].profiled_units
        pu.invest[1] > 0.0 || continue
        invest[pu.name, 0] = 0.0
        for t in 1:T
            invest[pu.name, t] = @variable(model, binary = true)
        end
    end
end

function _add_profiled_obj!(
    model::JuMP.Model,
    instance::UnitCommitmentInstance,
)::Nothing
    T = instance.time
    prod = model[:prod]
    invest = model[:invest]

    # Production costs
    for t in 1:T, sc in instance.scenarios, pu in sc.profiled_units
        add_to_expression!(
            model[:obj],
            prod[sc.name, pu.name, t],
            pu.cost[t] * sc.probability,
        )
    end

    # Investment costs
    for pu in instance.scenarios[1].profiled_units
        pu.invest[1] > 0.0 || continue
        for t in 1:T
            add_to_expression!(
                model[:obj],
                invest[pu.name, t] - invest[pu.name, t-1],
                pu.invest[t] * instance.scenarios[1].investment_cost_weight,
            )
        end
    end

    return
end

function _add_profiled_constr_invest!(
    model::JuMP.Model,
    instance::UnitCommitmentInstance,
)::Nothing
    T = instance.time
    prod = model[:prod]
    invest = model[:invest]
    eq_invest_nondec = _init(model, :eq_invest_nondec)
    eq_invest_prod_ub = _init(model, :eq_invest_prod_ub)
    eq_invest_prod_lb = _init(model, :eq_invest_prod_lb)

    # Once invested, the investment is irreversible
    for pu in instance.scenarios[1].profiled_units
        pu.invest[1] > 0.0 || continue
        for t in 2:T
            eq_invest_nondec[pu.name, t] = @constraint(
                model,
                invest[pu.name, t-1] <= invest[pu.name, t],
            )
        end
    end

    # Production is bounded by capacity only if invested
    for sc in instance.scenarios, pu in sc.profiled_units
        pu.invest[1] > 0.0 || continue

        for t in 1:T
            eq_invest_prod_ub[sc.name, pu.name, t] = @constraint(
                model,
                prod[sc.name, pu.name, t] <=
                pu.max_power[t] * invest[pu.name, t],
            )
            eq_invest_prod_lb[sc.name, pu.name, t] = @constraint(
                model,
                prod[sc.name, pu.name, t] >=
                pu.min_power[t] * invest[pu.name, t],
            )
        end
    end

    return
end
