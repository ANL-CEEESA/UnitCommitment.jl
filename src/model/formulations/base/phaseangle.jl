# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

function _add_planning_unified!(
    model::JuMP.Model,
    pu::ProfiledUnit,
    lm::TransmissionLine,
    sc::UnitCommitmentScenario,
)::Nothing
    invest_unit = _init(model, :invest_unit)
    invest_line = _init(model, :invest_line)
    eq_invest_unit_history = _init(model, :eq_invest_unit_history)
    eq_invest_line_history = _init(model, :eq_invest_line_history)
    eq_invest_unit_capacity = _init(model, :eq_invest_unit_capacity)

    # t == 0
    # TODO: If investment cost is zero, skip creating these investment variables
    invest_unit[sc.name, pu.name, 0] = @variable(
        model, 
        binary = true, 
        fixed = pu.invest == 0.0
    )
    invest_line[sc.name, lm.name, 0] = Int(lm.invest == 0.0) 

    for t in 1:model[:instance].time
        # Decision variable
        invest_unit[sc.name, pu.name, t] = @variable(model, binary = true)
        invest_line[sc.name, lm.name, t] = @variable(model, binary = true)

        # Objective function terms
        add_to_expression!(
            model[:obj],
            invest_unit[sc.name, pu.name, t] - invest_unit[sc.name, pu.name, t-1],
            pu.invest[t] * sc.probability,
        )
        add_to_expression!(
            model[:obj],
            invest_line[sc.name, lm.name, t] - invest_line[sc.name, lm.name, t-1],
            lm.invest[t] * sc.probability,
        )

        # Investment constraints
        # (1c) in the paper
        eq_invest_unit_history[sc.name, pu.name, t] = @constraint(
            model,
            invest_unit[sc.name, pu.name, t-1] <= invest_unit[sc.name, pu.name, t]
        )
        # (1d) in the paper
        eq_invest_line_history[sc.name, lm.name, t] = @constraint(
            model,
            invest_line[sc.name, lm.name, t-1] <= invest_line[sc.name, lm.name, t]
        )
        # (1h) in the paper TODO: separate this to two halves
        eq_invest_unit_capacity[sc.name, pu.name, t] = @constraint(
            model,
            pu.min_power[t] * invest_unit[sc.name, pu.name, t] <= 
            model[:prod_above][sc.name, pu.name, t] <= 
            pu.max_power[t] * invest_unit[sc.name, pu.name, t]
        )
    end
    return
end

# TODO: add max_copy constraint
function _add_planning_new_lines!(
    model::JuMP.Model,
    lm::TransmissionLine,
    bs::Bus,
    f::PhaseAngleFormulation,
    sc::UnitCommitmentScenario,
)::Nothing
    θ = _init(model, :theta)
    flow = _init(model, :flow)
    invest_line = model[:invest_line]
    eq_invest_line_flow_a = _init(model, :eq_invest_line_flow_a)
    eq_invest_line_flow_b = _init(model, :eq_invest_line_flow_b)
    eq_invest_line_flow_limit = _init(model, :eq_invest_line_flow_limit)

    bigM = 1e6  # TODO: make this a parameter

    for t in 1:model[:instance].time
        # TODO: add bus field: phase_angle_limit? give default
        θ[sc.name, bs.name, t] = @variable(model, lower_bound = -pi, upper_bound = pi)
        flow[sc.name, lm.name, t] = @variable(model)

        # (2b)
        eq_invest_line_flow_a[sc.name, lm.name, t] = @constraint(
            model,
            model[:flow][sc.name, lm.name, t] <=
            lm.susceptance * (θ[sc.name, lm.source.name, t] - θ[sc.name, lm.target.name, t]) 
            + bigM * (1 - invest_line[sc.name, lm.name, t])
        )
        # (2c)
        eq_invest_line_flow_b[sc.name, lm.name, t] = @constraint(
            model,
            model[:flow][sc.name, lm.name, t] >=
            lm.susceptance * (θ[sc.name, lm.source.name, t] - θ[sc.name, lm.target.name, t]) 
            - bigM * (1 - invest_line[sc.name, lm.name, t])
        )
        # (2d)
        eq_invest_line_flow_limit[sc.name, lm.name, t] = @constraint(
            model,
            -lm.normal_flow_limit[t] * invest_line[sc.name, lm.name, t] <= 
            model[:flow][sc.name, lm.name, t] <= 
            lm.normal_flow_limit[t] * invest_line[sc.name, lm.name, t]
        )
    end
    return
end