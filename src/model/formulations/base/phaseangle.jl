# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

function _add_transmission_line!(
    model::JuMP.Model,
    lm::TransmissionLine,
    f::PhaseAngleFormulation,
    sc::UnitCommitmentScenario,
)::Nothing
    # Overflow (same as in shiftfactor.jl)
    overflow = _init(model, :overflow)
    for t in 1:model[:instance].time
        overflow[sc.name, lm.name, t] = @variable(model, lower_bound = 0)
        add_to_expression!(
            model[:obj],
            overflow[sc.name, lm.name, t],
            lm.flow_limit_penalty[t] * sc.probability,
        )
    end

    # Transmission expansion
    θ = model[:theta]
    flow = _init(model, :flow)
    if lm.max_copy > 1 || lm.invest[1] == 0.0
        eq_invest_line_flow = _init(model, :eq_invest_line_flow)
    else
        eq_invest_line_flow_upper = _init(model, :eq_invest_line_flow_upper)
        eq_invest_line_flow_lower = _init(model, :eq_invest_line_flow_lower)
    end
    eq_invest_line_flow_limit_upper =
        _init(model, :eq_invest_line_flow_limit_upper)
    eq_invest_line_flow_limit_lower =
        _init(model, :eq_invest_line_flow_limit_lower)

    if lm.invest[1] > 0.0
        invest_line = _init(model, :invest_line)
        eq_invest_line_nondecreasing =
            _init(model, :eq_invest_line_nondecreasing)

        add_first_stage = !haskey(invest_line, (lm.name, 1))

        if add_first_stage
            invest_line[lm.name, 0] = 0.0
        end

        for t in 1:model[:instance].time
            # Decision variable
            if add_first_stage
                invest_line[lm.name, t] = @variable(
                    model,
                    lower_bound = 0,
                    upper_bound = lm.max_copy,
                    integer = true
                )

                # Objective function terms
                add_to_expression!(
                    model[:obj],
                    invest_line[lm.name, t] - invest_line[lm.name, t-1],
                    lm.invest[t],
                )

                # Investment constraints
                eq_invest_line_nondecreasing[lm.name, t] = @constraint(
                    model,
                    invest_line[lm.name, t-1] <= invest_line[lm.name, t]
                )
            end

            flow[sc.name, lm.name, t] = @variable(model)

            # Power flow constraints
            if lm.max_copy > 1
                eq_invest_line_flow[sc.name, lm.name, t] = @constraint(
                    model,
                    model[:flow][sc.name, lm.name, t] ==
                    invest_line[lm.name, t] *
                    f.s_base *
                    lm.susceptance *
                    (
                        θ[sc.name, lm.source.name, t] -
                        θ[sc.name, lm.target.name, t]
                    )
                )
            else
                eq_invest_line_flow_upper[sc.name, lm.name, t] = @constraint(
                    model,
                    model[:flow][sc.name, lm.name, t] <=
                    f.s_base *
                    lm.susceptance *
                    (
                        θ[sc.name, lm.source.name, t] -
                        θ[sc.name, lm.target.name, t]
                    ) + f.bigM * (1 - invest_line[lm.name, t])
                )
                eq_invest_line_flow_lower[sc.name, lm.name, t] = @constraint(
                    model,
                    model[:flow][sc.name, lm.name, t] >=
                    f.s_base *
                    lm.susceptance *
                    (
                        θ[sc.name, lm.source.name, t] -
                        θ[sc.name, lm.target.name, t]
                    ) - f.bigM * (1 - invest_line[lm.name, t])
                )
            end
            eq_invest_line_flow_limit_upper[sc.name, lm.name, t] = @constraint(
                model,
                model[:flow][sc.name, lm.name, t] <=
                lm.normal_flow_limit[t] * invest_line[lm.name, t]
            )
            eq_invest_line_flow_limit_lower[sc.name, lm.name, t] = @constraint(
                model,
                model[:flow][sc.name, lm.name, t] >=
                -lm.normal_flow_limit[t] * invest_line[lm.name, t]
            )
        end
    else
        # No investment
        for t in 1:model[:instance].time
            # Decision variable
            flow[sc.name, lm.name, t] = @variable(model)

            # Power flow constraints
            eq_invest_line_flow[sc.name, lm.name, t] = @constraint(
                model,
                model[:flow][sc.name, lm.name, t] ==
                f.s_base *
                lm.susceptance *
                (θ[sc.name, lm.source.name, t] - θ[sc.name, lm.target.name, t])
            )
            eq_invest_line_flow_limit_upper[sc.name, lm.name, t] = @constraint(
                model,
                model[:flow][sc.name, lm.name, t] <= lm.normal_flow_limit[t]
            )
            eq_invest_line_flow_limit_lower[sc.name, lm.name, t] = @constraint(
                model,
                model[:flow][sc.name, lm.name, t] >= -lm.normal_flow_limit[t]
            )
        end
    end

    return
end

function _setup_transmission(
    model::JuMP.Model,
    formulation::PhaseAngleFormulation,
    sc::UnitCommitmentScenario,
)::Nothing
    θ = _init(model, :theta)
    for t in 1:model[:instance].time
        for b in sc.buses
            θ[sc.name, b.name, t] = @variable(
                model,
                lower_bound = -formulation.phase_angle_limit,
                upper_bound = formulation.phase_angle_limit
            )
        end
        fix(θ[sc.name, sc.buses[1].name, t], 0.0; force = true) # reference bus
    end
    return
end
