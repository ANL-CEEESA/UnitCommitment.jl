# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

function _add_profiled_unit!(
    model::JuMP.Model,
    pu::ProfiledUnit,
    sc::UnitCommitmentScenario,
)::Nothing
    punits = _init(model, :prod_profiled)
    net_injection = _init(model, :expr_net_injection)
    for t in 1:model[:instance].time
        # Decision variable
        punits[sc.name, pu.name, t] = @variable(
            model,
            lower_bound = pu.min_power[t],
            upper_bound = pu.max_power[t]
        )

        # Objective function terms
        add_to_expression!(
            model[:obj],
            punits[sc.name, pu.name, t],
            pu.cost[t] * sc.probability,
        )

        # Net injection
        add_to_expression!(
            net_injection[sc.name, pu.bus.name, t],
            punits[sc.name, pu.name, t],
            1.0,
        )
    end

    # Generation expansion
    if pu.invest[1] > 0.0
        invest_unit = _init(model, :invest_unit)
        eq_invest_unit_nondecreasing =
            _init(model, :eq_invest_unit_nondecreasing)
        eq_invest_unit_capacity_upper =
            _init(model, :eq_invest_unit_capacity_upper)
        eq_invest_unit_capacity_lower =
            _init(model, :eq_invest_unit_capacity_lower)

        add_first_stage = !haskey(invest_unit, (pu.name, 1))

        if add_first_stage
            invest_unit[pu.name, 0] = 0.0
        end

        for t in 1:model[:instance].time
            # Decision variable
            if add_first_stage
                invest_unit[pu.name, t] = @variable(model, binary = true)

                # Objective function terms
                add_to_expression!(
                    model[:obj],
                    invest_unit[pu.name, t] - invest_unit[pu.name, t-1],
                    pu.invest[t] * sc.investment_cost_weight,
                )

                # Investment constraints
                eq_invest_unit_nondecreasing[pu.name, t] = @constraint(
                    model,
                    invest_unit[pu.name, t-1] <= invest_unit[pu.name, t]
                )
            end

            eq_invest_unit_capacity_upper[sc.name, pu.name, t] = @constraint(
                model,
                punits[sc.name, pu.name, t] <=
                pu.max_power[t] * invest_unit[pu.name, t]
            )
            eq_invest_unit_capacity_lower[sc.name, pu.name, t] = @constraint(
                model,
                punits[sc.name, pu.name, t] >=
                pu.min_power[t] * invest_unit[pu.name, t]
            )
        end
    end

    return
end
