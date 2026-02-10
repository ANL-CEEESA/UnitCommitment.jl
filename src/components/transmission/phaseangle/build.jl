# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using JuMP

function build_model(
    model::JuMP.Model,
    instance::UnitCommitmentInstance,
    ext::PhaseAngleTransmissionExt,
)::Nothing
    _add_transmission_vars!(model, instance, ext)
    _add_transmission_obj!(model, instance)
    _add_transmission_constr_flow!(model, instance, ext)
    _add_transmission_constr_nodal_balance!(model, instance)
    _add_transmission_constr_invest!(model, instance)
    return
end

function _add_transmission_vars!(
    model::JuMP.Model,
    instance::UnitCommitmentInstance,
    ext::PhaseAngleTransmissionExt,
)::Nothing
    T = instance.time

    theta = _init(model, :theta)
    overflow = _init(model, :overflow)
    flow = _init(model, :flow)
    invest = _init(model, :invest)

    for line in instance.scenarios[1][:lines]
        line.invest[1] > 0.0 || continue
        invest[line.name, 0] = 0.0
        for t in 1:T
            invest[line.name, t] = @variable(
                model,
                lower_bound = 0,
                upper_bound = line.max_copy,
                integer = true
            )
        end
    end

    # Phase angle variables
    for sc in instance.scenarios, t in 1:T
        for b in sc[:bus]
            theta[sc.name, b.name, t] = @variable(
                model,
                lower_bound = -ext.phase_angle_limit,
                upper_bound = ext.phase_angle_limit
            )
        end
        fix(theta[sc.name, sc[:bus][1].name, t], 0.0; force = true)
    end

    for sc in instance.scenarios, line in sc[:lines], t in 1:T
        # Overflow variable for soft flow limit constraints
        overflow[sc.name, line.name, t] = @variable(model, lower_bound = 0)

        # Flow variable
        flow[sc.name, line.name, t] = @variable(model)
    end
    return
end

function _add_transmission_obj!(
    model::JuMP.Model,
    instance::UnitCommitmentInstance,
)::Nothing
    T = instance.time
    overflow = model[:overflow]
    invest = model[:invest]

    # Overflow penalty
    for sc in instance.scenarios, line in sc[:lines], t in 1:T
        add_to_expression!(
            model[:obj],
            overflow[sc.name, line.name, t],
            line.flow_limit_penalty[t] * sc[:probability],
        )
    end

    # Investment cost
    for line in instance.scenarios[1][:lines]
        line.invest[1] > 0.0 || continue
        for t in 1:T
            add_to_expression!(
                model[:obj],
                invest[line.name, t] - invest[line.name, t-1],
                line.invest[t] * instance.scenarios[1][:investment_cost_weight],
            )
        end
    end
    return
end

function _add_transmission_constr_flow!(
    model::JuMP.Model,
    instance::UnitCommitmentInstance,
    ext::PhaseAngleTransmissionExt,
)::Nothing
    T = instance.time

    theta = model[:theta]
    flow = model[:flow]
    overflow = model[:overflow]
    invest = model[:invest]

    # DC power flow equation: flow = susceptance * (theta_source - theta_target)
    eq_dc_flow = _init(model, :eq_dc_flow)

    # Big-M formulation for binary investment decisions (single copy lines)
    eq_dc_flow_bigm_ub = _init(model, :eq_dc_flow_bigm_ub)
    eq_dc_flow_bigm_lb = _init(model, :eq_dc_flow_bigm_lb)

    # Flow capacity limits (with overflow penalty)
    eq_flow_limit_ub = _init(model, :eq_flow_limit_ub)
    eq_flow_limit_lb = _init(model, :eq_flow_limit_lb)

    for sc in instance.scenarios
        lines = sc[:lines]

        for line in lines, t in 1:T
            # Compute angle difference
            angle_diff =
                theta[sc.name, line.source.name, t] -
                theta[sc.name, line.target.name, t]

            if line.invest[1] > 0.0
                # Investment lines
                if line.max_copy > 1
                    # Multiple parallel circuits: flow = invest * susceptance * angle_diff
                    eq_dc_flow[sc.name, line.name, t] = @constraint(
                        model,
                        flow[sc.name, line.name, t] ==
                        invest[line.name, t] * line.susceptance * angle_diff
                    )
                else
                    # Single circuit with big-M formulation
                    # When invest=1: flow = susceptance * angle_diff
                    # When invest=0: flow is unconstrained (big-M makes constraints inactive)
                    eq_dc_flow_bigm_ub[sc.name, line.name, t] = @constraint(
                        model,
                        flow[sc.name, line.name, t] <=
                        line.susceptance * angle_diff +
                        ext.bigM * (1 - invest[line.name, t])
                    )
                    eq_dc_flow_bigm_lb[sc.name, line.name, t] = @constraint(
                        model,
                        flow[sc.name, line.name, t] >=
                        line.susceptance * angle_diff -
                        ext.bigM * (1 - invest[line.name, t])
                    )
                end

                # Flow capacity limits (scaled by investment)
                eq_flow_limit_ub[sc.name, line.name, t] = @constraint(
                    model,
                    flow[sc.name, line.name, t] <=
                    line.normal_flow_limit[t] * invest[line.name, t] +
                    overflow[sc.name, line.name, t]
                )
                eq_flow_limit_lb[sc.name, line.name, t] = @constraint(
                    model,
                    flow[sc.name, line.name, t] >=
                    -line.normal_flow_limit[t] * invest[line.name, t] -
                    overflow[sc.name, line.name, t]
                )
            else
                # Non-investment lines (standard DC power flow)
                eq_dc_flow[sc.name, line.name, t] = @constraint(
                    model,
                    flow[sc.name, line.name, t] ==
                    line.susceptance * angle_diff
                )

                # Flow capacity limits (fixed)
                eq_flow_limit_ub[sc.name, line.name, t] = @constraint(
                    model,
                    flow[sc.name, line.name, t] <=
                    line.normal_flow_limit[t] + overflow[sc.name, line.name, t]
                )
                eq_flow_limit_lb[sc.name, line.name, t] = @constraint(
                    model,
                    flow[sc.name, line.name, t] >=
                    -line.normal_flow_limit[t] -
                    overflow[sc.name, line.name, t]
                )
            end
        end
    end
    return
end

function _add_transmission_constr_nodal_balance!(
    model::JuMP.Model,
    instance::UnitCommitmentInstance,
)::Nothing
    T = instance.time
    flow = model[:flow]
    eq_nodal_balance = _init(model, :eq_nodal_balance)

    for sc in instance.scenarios
        lines = sc[:lines]
        for t in 1:T
            for b in sc[:bus]
                eq_nodal_balance[sc.name, b.name, t] = @constraint(
                    model,
                    sum(
                        flow[sc.name, lm.name, t] for
                        lm in lines if lm.source == b
                    ) - sum(
                        flow[sc.name, lm.name, t] for
                        lm in lines if lm.target == b
                    ) + model[:ni][sc.name, b.name, t] == 0
                )
            end
        end
    end
    return
end

function _add_transmission_constr_invest!(
    model::JuMP.Model,
    instance::UnitCommitmentInstance,
)::Nothing
    T = instance.time
    invest = model[:invest]
    eq_invest_nondec = _init(model, :eq_invest_nondec)

    # Investment is irreversible
    for line in instance.scenarios[1][:lines]
        if line.invest[1] > 0.0
            for t in 2:T
                eq_invest_nondec[line.name, t] = @constraint(
                    model,
                    invest[line.name, t-1] <= invest[line.name, t],
                )
            end
        end
    end
    return
end
