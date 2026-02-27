# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using JuMP

function build_model(
    model::JuMP.Model,
    instance::UnitCommitmentInstance,
    ext::PhaseAngleTransmissionExt,
)::Nothing
    build_model(model, instance, CopperPlateTransmissionExt())
    _check(instance, ext)
    _add_dc_vars!(model, instance, ext)
    _add_dc_obj!(model, instance, ext)
    _add_dc_constr_flow!(model, instance, ext)
    _add_dc_constr_nodal_balance!(model, instance, ext)
    _add_dc_constr_invest!(model, instance, ext)
    _add_dc_constr_angle_diff!(model, instance, ext)
    return
end

function _interface_flow_expr(
    model::JuMP.Model,
    sc::UnitCommitmentScenario,
    ifc::Interface,
    t::Int,
    ::PhaseAngleTransmissionExt,
)
    flow = model[:flow]
    expr = AffExpr(0.0)
    for branch in ifc.branches
        w = ifc.weight_by_branch[branch]
        add_to_expression!(expr, flow[sc.name, branch.name, t], w)
    end
    return expr
end

function _check(
    instance::UnitCommitmentInstance,
    ::PhaseAngleTransmissionExt,
)::Nothing
    # Check for contingencies - this extension does not support them
    for sc in instance.scenarios
        if !isempty(sc[:contingencies])
            error(
                "PhaseAngleTransmissionExt does not support contingencies. " *
                "Scenario '$(sc.name)' has $(length(sc[:contingencies])) contingency/contingencies.",
            )
        end
    end
    return
end

function _add_dc_vars!(
    model::JuMP.Model,
    instance::UnitCommitmentInstance,
    ext::PhaseAngleTransmissionExt,
)::Nothing
    T = instance.time

    theta = _init(model, :theta)
    overflow = _init(model, :overflow)
    flow = _init(model, :flow)
    invest = _init(model, :invest)

    for branch in instance.scenarios[1][:branches]
        branch.invest[1] > 0.0 || continue
        invest[branch.name, 0] = 0.0
        for t in 1:T
            invest[branch.name, t] = @variable(
                model,
                lower_bound = 0,
                upper_bound = branch.max_copy,
                integer = true
            )
        end
    end

    # Phase angle variables
    for sc in instance.scenarios
        ref_buses = [b for b in sc[:bus] if b.bus_type == "Slack"]
        if isempty(ref_buses)
            ref_buses = [sc[:bus][1]]
        end
        for t in 1:T
            for b in sc[:bus]
                theta[sc.name, b.name, t] = @variable(
                    model,
                    lower_bound = -ext.phase_angle_limit,
                    upper_bound = ext.phase_angle_limit
                )
            end
            for b in ref_buses
                fix(theta[sc.name, b.name, t], 0.0; force = true)
            end
        end
    end

    for sc in instance.scenarios, branch in sc[:branches], t in 1:T
        # Overflow variable for soft flow limit constraints
        overflow[sc.name, branch.name, t] = @variable(model, lower_bound = 0)

        # Flow variable
        flow[sc.name, branch.name, t] = @variable(model)
    end
    return
end

function _add_dc_constr_flow!(
    model::JuMP.Model,
    instance::UnitCommitmentInstance,
    ext::PhaseAngleTransmissionExt,
)::Nothing
    T = instance.time

    theta = model[:theta]
    flow = model[:flow]
    overflow = model[:overflow]
    invest = model[:invest]

    eq_dc_flow = _init(model, :eq_dc_flow)
    eq_dc_flow_bigm_ub = _init(model, :eq_dc_flow_bigm_ub)
    eq_dc_flow_bigm_lb = _init(model, :eq_dc_flow_bigm_lb)
    eq_flow_limit_ub = _init(model, :eq_flow_limit_ub)
    eq_flow_limit_lb = _init(model, :eq_flow_limit_lb)

    for sc in instance.scenarios
        branches = sc[:branches]

        for branch in branches, t in 1:T
            # Susceptance in MW/rad: B_pu * base_mva = MW/rad
            b = branch.susceptance * sc[:base_mva]

            # Compute angle difference
            angle_diff =
                theta[sc.name, branch.source.name, t] -
                theta[sc.name, branch.target.name, t]

            if branch.invest[1] > 0.0
                # Investment branches
                if branch.max_copy > 1
                    # Multiple parallel circuits: flow = invest * b * angle_diff
                    eq_dc_flow[sc.name, branch.name, t] = @constraint(
                        model,
                        flow[sc.name, branch.name, t] ==
                        invest[branch.name, t] * b * angle_diff
                    )
                else
                    # Single circuit with big-M formulation
                    # When invest=1: flow = b * angle_diff
                    # When invest=0: flow is unconstrained (big-M makes constraints inactive)
                    eq_dc_flow_bigm_ub[sc.name, branch.name, t] = @constraint(
                        model,
                        flow[sc.name, branch.name, t] <=
                        b * angle_diff +
                        ext.big_m * (1 - invest[branch.name, t])
                    )
                    eq_dc_flow_bigm_lb[sc.name, branch.name, t] = @constraint(
                        model,
                        flow[sc.name, branch.name, t] >=
                        b * angle_diff -
                        ext.big_m * (1 - invest[branch.name, t])
                    )
                end

                # Flow capacity limits (scaled by investment)
                eq_flow_limit_ub[sc.name, branch.name, t] = @constraint(
                    model,
                    flow[sc.name, branch.name, t] <=
                    branch.normal_flow_limit[t] * invest[branch.name, t] +
                    overflow[sc.name, branch.name, t]
                )
                eq_flow_limit_lb[sc.name, branch.name, t] = @constraint(
                    model,
                    flow[sc.name, branch.name, t] >=
                    -branch.normal_flow_limit[t] * invest[branch.name, t] -
                    overflow[sc.name, branch.name, t]
                )
            else
                # Non-investment branches (standard DC power flow)
                eq_dc_flow[sc.name, branch.name, t] = @constraint(
                    model,
                    flow[sc.name, branch.name, t] == b * angle_diff
                )

                # Flow capacity limits (fixed)
                eq_flow_limit_ub[sc.name, branch.name, t] = @constraint(
                    model,
                    flow[sc.name, branch.name, t] <=
                    branch.normal_flow_limit[t] +
                    overflow[sc.name, branch.name, t]
                )
                eq_flow_limit_lb[sc.name, branch.name, t] = @constraint(
                    model,
                    flow[sc.name, branch.name, t] >=
                    -branch.normal_flow_limit[t] -
                    overflow[sc.name, branch.name, t]
                )
            end
        end
    end
    return
end

function _add_dc_constr_nodal_balance!(
    model::JuMP.Model,
    instance::UnitCommitmentInstance,
    ext::PhaseAngleTransmissionExt,
)::Nothing
    T = instance.time
    flow = model[:flow]
    eq_nodal_balance = _init(model, :eq_nodal_balance)

    for sc in instance.scenarios
        branches = sc[:branches]
        for t in 1:T
            for b in sc[:bus]
                # Shunt conductance losses: gs * Vm^2 * baseMVA [MW]
                # Under DC approximation, Vm = 1.0 p.u.
                shunt_loss = AffExpr(0.0)
                for sh in sc[:shunts_by_bus][b]
                    if sh.status[t]
                        add_to_expression!(
                            shunt_loss,
                            sh.conductance * sc[:base_mva],
                        )
                    end
                end

                eq_nodal_balance[sc.name, b.name, t] = @constraint(
                    model,
                    model[:ni][sc.name, b.name, t] - shunt_loss + sum(
                        flow[sc.name, lm.name, t] for
                        lm in branches if lm.target == b
                    ) == sum(
                        flow[sc.name, lm.name, t] for
                        lm in branches if lm.source == b
                    )
                )
            end
        end
    end
    return
end

function _add_dc_constr_invest!(
    model::JuMP.Model,
    instance::UnitCommitmentInstance,
    ext::PhaseAngleTransmissionExt,
)::Nothing
    T = instance.time
    invest = model[:invest]
    eq_invest_nondec = _init(model, :eq_invest_nondec)

    # Investment is irreversible
    for branch in instance.scenarios[1][:branches]
        if branch.invest[1] > 0.0
            for t in 2:T
                eq_invest_nondec[branch.name, t] = @constraint(
                    model,
                    invest[branch.name, t-1] <= invest[branch.name, t],
                )
            end
        end
    end
    return
end

function _add_dc_constr_angle_diff!(
    model::JuMP.Model,
    instance::UnitCommitmentInstance,
    ext::PhaseAngleTransmissionExt,
)::Nothing
    T = instance.time
    theta = model[:theta]

    eq_angle_diff_ub = _init(model, :eq_angle_diff_ub)
    eq_angle_diff_lb = _init(model, :eq_angle_diff_lb)

    for sc in instance.scenarios, branch in sc[:branches], t in 1:T
        angle_diff =
            theta[sc.name, branch.source.name, t] -
            theta[sc.name, branch.target.name, t]

        if isfinite(branch.angle_diff_max)
            eq_angle_diff_ub[sc.name, branch.name, t] =
                @constraint(model, angle_diff <= branch.angle_diff_max)
        end
        if isfinite(branch.angle_diff_min)
            eq_angle_diff_lb[sc.name, branch.name, t] =
                @constraint(model, angle_diff >= branch.angle_diff_min)
        end
    end
    return
end
