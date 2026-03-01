# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using JuMP

function _check(
    instance::UnitCommitmentInstance,
    ext::ShiftFactorsTransmissionExt,
)::Nothing
    if ext.lazy && any(!isempty(sc[:shunts]) for sc in instance.scenarios)
        error(
            "ShiftFactorsTransmissionExt with lazy=true is not supported " *
            "when the instance has shunt devices. Use lazy=false or " *
            "PhaseAngleTransmissionExt instead.",
        )
    end
    for sc in instance.scenarios
        for branch in sc[:branches]
            if branch.invest[1] > 0.0
                error(
                    "ShiftFactorsTransmissionExt does not support branch investment. " *
                    "Branch '$(branch.name)' has investment cost $(branch.invest[1]). " *
                    "Use PhaseAngleTransmissionExt instead.",
                )
            end
            if isfinite(branch.angle_diff_min) ||
               isfinite(branch.angle_diff_max)
                error(
                    "Branch '$(branch.name)' has finite angle difference limits, " *
                    "which are not supported by ShiftFactorsTransmissionExt. " *
                    "Use PhaseAngleTransmissionExt instead.",
                )
            end
        end
        for cont in sc[:contingencies]
            length(cont.branches) == 1 || error(
                "ShiftFactorsTransmissionExt only supports contingencies with exactly one " *
                "outage branch. Contingency '$(cont.name)' has $(length(cont.branches)) branches.",
            )
        end
    end
    return
end

function _add_dc_vars!(
    model::JuMP.Model,
    instance::UnitCommitmentInstance,
    ext::ShiftFactorsTransmissionExt,
)::Nothing
    T = instance.time

    overflow = _init(model, :overflow)

    # Overflow variables (shared between base and contingency cases)
    for sc in instance.scenarios, branch in sc[:branches], t in 1:T
        if branch.flow_limit_penalty[t] < 0
            overflow[sc.name, branch.name, t] = 0.0
        else
            overflow[sc.name, branch.name, t] =
                @variable(model, lower_bound = 0)
        end
    end

    if !ext.lazy
        flow = _init(model, :flow)
        flow_cont = _init(model, :flow_cont)

        # Base case flow variables
        for sc in instance.scenarios, branch in sc[:branches], t in 1:T
            flow[sc.name, branch.name, t] = @variable(model)
        end

        # Contingency flow variables
        for sc in instance.scenarios, cont in sc[:contingencies]
            for branch in sc[:branches], t in 1:T
                flow_cont[sc.name, cont.name, branch.name, t] = @variable(model)
            end
        end
    end

    return
end

function _add_dc_constr_flow!(
    model::JuMP.Model,
    instance::UnitCommitmentInstance,
    ext::ShiftFactorsTransmissionExt,
)::Nothing
    ext.lazy && return
    T = instance.time
    ni = model[:ni]
    flow = model[:flow]
    flow_cont = model[:flow_cont]
    overflow = model[:overflow]

    eq_flow_def = _init(model, :eq_flow_def)
    eq_flow_limit_ub = _init(model, :eq_flow_limit_ub)
    eq_flow_limit_lb = _init(model, :eq_flow_limit_lb)
    eq_flow_cont_def = _init(model, :eq_flow_cont_def)
    eq_flow_cont_limit_ub = _init(model, :eq_flow_cont_limit_ub)
    eq_flow_cont_limit_lb = _init(model, :eq_flow_cont_limit_lb)

    for sc in instance.scenarios
        length(sc[:branches]) > 0 || continue

        isf = sc[:isf]
        lodf = sc[:lodf]
        branches = sc[:branches]
        buses = sc[:bus]

        shunt_loss = _shunt_loss_matrix(sc, T)
        branch_shunt_corr = isf * shunt_loss

        # Base case constraints
        for branch in branches, t in 1:T
            # Flow definition using ISF: flow = sum(ISF[l,b] * (ni[b] - shunt_loss[b]))
            flow_expr = AffExpr(0.0)
            for bus in buses
                bus.offset > 0 || continue
                coef = isf[branch.offset, bus.offset]
                coef == 0.0 && continue
                add_to_expression!(flow_expr, ni[sc.name, bus.name, t], coef)
            end

            eq_flow_def[sc.name, branch.name, t] = @constraint(
                model,
                flow[sc.name, branch.name, t] ==
                flow_expr - branch_shunt_corr[branch.offset, t]
            )

            # Flow limits (base case uses normal_flow_limit)
            eq_flow_limit_ub[sc.name, branch.name, t] = @constraint(
                model,
                flow[sc.name, branch.name, t] <=
                branch.normal_flow_limit[t] + overflow[sc.name, branch.name, t]
            )
            eq_flow_limit_lb[sc.name, branch.name, t] = @constraint(
                model,
                flow[sc.name, branch.name, t] >=
                -branch.normal_flow_limit[t] -
                overflow[sc.name, branch.name, t]
            )
        end

        # Contingency case constraints
        for cont in sc[:contingencies]
            for outage_branch in cont.branches
                for monitored_branch in branches, t in 1:T
                    # Flow definition using ISF + LODF
                    # flow = sum((ISF[m,b] + LODF[m,o]*ISF[o,b]) * (ni[b] - shunt_loss[b]))
                    flow_expr = AffExpr(0.0)
                    lodf_coef =
                        lodf[monitored_branch.offset, outage_branch.offset]

                    for bus in buses
                        bus.offset > 0 || continue

                        # Base ISF term
                        isf_mon = isf[monitored_branch.offset, bus.offset]

                        # Combined coefficient with LODF correction
                        total_coef = isf_mon
                        if lodf_coef != 0.0
                            isf_out = isf[outage_branch.offset, bus.offset]
                            if isf_out != 0.0
                                total_coef += lodf_coef * isf_out
                            end
                        end

                        total_coef == 0.0 && continue
                        add_to_expression!(
                            flow_expr,
                            ni[sc.name, bus.name, t],
                            total_coef,
                        )
                    end

                    shunt_corr =
                        branch_shunt_corr[monitored_branch.offset, t] +
                        lodf_coef * branch_shunt_corr[outage_branch.offset, t]

                    eq_flow_cont_def[
                        sc.name,
                        cont.name,
                        monitored_branch.name,
                        t,
                    ] = @constraint(
                        model,
                        flow_cont[
                            sc.name,
                            cont.name,
                            monitored_branch.name,
                            t,
                        ] == flow_expr - shunt_corr
                    )

                    # Emergency flow limits (contingency uses emergency_flow_limit, same overflow variable)
                    eq_flow_cont_limit_ub[
                        sc.name,
                        cont.name,
                        monitored_branch.name,
                        t,
                    ] = @constraint(
                        model,
                        flow_cont[
                            sc.name,
                            cont.name,
                            monitored_branch.name,
                            t,
                        ] <=
                        monitored_branch.emergency_flow_limit[t] +
                        overflow[sc.name, monitored_branch.name, t]
                    )
                    eq_flow_cont_limit_lb[
                        sc.name,
                        cont.name,
                        monitored_branch.name,
                        t,
                    ] = @constraint(
                        model,
                        flow_cont[
                            sc.name,
                            cont.name,
                            monitored_branch.name,
                            t,
                        ] >=
                        -monitored_branch.emergency_flow_limit[t] -
                        overflow[sc.name, monitored_branch.name, t]
                    )
                end
            end
        end
    end
    return
end

function _interface_flow_expr(
    model::JuMP.Model,
    sc::UnitCommitmentScenario,
    ifc::Interface,
    t::Int,
    ::ShiftFactorsTransmissionExt,
)
    ni = model[:ni]
    ifc_isf = sc[:interface_isf]
    buses = sc[:bus]
    expr = AffExpr(0.0)
    shunt_correction = 0.0
    for bus in buses
        bus.offset > 0 || continue
        coef = ifc_isf[ifc.offset, bus.offset]
        coef == 0.0 && continue
        add_to_expression!(expr, ni[sc.name, bus.name, t], coef)
        shunt_correction += coef * _bus_shunt_loss(sc, bus, t)
    end
    return expr - shunt_correction
end
