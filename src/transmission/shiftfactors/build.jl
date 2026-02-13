# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using JuMP

function build_model(
    model::JuMP.Model,
    instance::UnitCommitmentInstance,
    ext::ShiftFactorsTransmissionExt,
)::Nothing
    build_model(model, instance, CopperPlateTransmissionExt())
    _add_transmission_vars!(model, instance, ext)
    _add_transmission_obj!(model, instance, ext)
    _add_transmission_constr_flow!(model, instance, ext)
    return
end

function _add_transmission_vars!(
    model::JuMP.Model,
    instance::UnitCommitmentInstance,
    ext::ShiftFactorsTransmissionExt,
)::Nothing
    T = instance.time

    overflow = _init(model, :overflow)

    # Overflow variables (shared between base and contingency cases)
    for sc in instance.scenarios, line in sc[:lines], t in 1:T
        overflow[sc.name, line.name, t] = @variable(model, lower_bound = 0)
    end

    if !ext.lazy
        flow = _init(model, :flow)
        flow_cont = _init(model, :flow_cont)

        # Base case flow variables
        for sc in instance.scenarios, line in sc[:lines], t in 1:T
            flow[sc.name, line.name, t] = @variable(model)
        end

        # Contingency flow variables
        for sc in instance.scenarios, cont in sc[:contingencies]
            for line in sc[:lines], t in 1:T
                flow_cont[sc.name, cont.name, line.name, t] = @variable(model)
            end
        end
    end

    return
end

function _add_transmission_obj!(
    model::JuMP.Model,
    instance::UnitCommitmentInstance,
    ext::ShiftFactorsTransmissionExt,
)::Nothing
    T = instance.time
    overflow = model[:overflow]

    # Overflow penalty (single penalty per line, shared across base and contingency cases)
    for sc in instance.scenarios, line in sc[:lines], t in 1:T
        add_to_expression!(
            model[:obj],
            overflow[sc.name, line.name, t],
            line.flow_limit_penalty[t] * sc[:probability],
        )
    end

    return
end

function _add_transmission_constr_flow!(
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
        length(sc[:lines]) > 0 || continue

        isf = sc[:isf]
        lodf = sc[:lodf]
        lines = sc[:lines]
        buses = sc[:bus]

        # Base case constraints
        for line in lines, t in 1:T
            # Flow definition using ISF: flow = sum(net_injection[bus] * isf[line, bus])
            flow_expr = AffExpr(0.0)
            for bus in buses
                bus.offset > 0 || continue
                coef = isf[line.offset, bus.offset]
                coef == 0.0 && continue
                add_to_expression!(flow_expr, ni[sc.name, bus.name, t], coef)
            end

            eq_flow_def[sc.name, line.name, t] =
                @constraint(model, flow[sc.name, line.name, t] == flow_expr)

            # Flow limits (base case uses normal_flow_limit)
            eq_flow_limit_ub[sc.name, line.name, t] = @constraint(
                model,
                flow[sc.name, line.name, t] <=
                line.normal_flow_limit[t] + overflow[sc.name, line.name, t]
            )
            eq_flow_limit_lb[sc.name, line.name, t] = @constraint(
                model,
                flow[sc.name, line.name, t] >=
                -line.normal_flow_limit[t] - overflow[sc.name, line.name, t]
            )
        end

        # Contingency case constraints
        for cont in sc[:contingencies]
            for outage_line in cont.lines
                for monitored_line in lines, t in 1:T
                    # Flow definition using ISF + LODF
                    # flow = sum(net_injection[bus] * (isf[monitored, bus] + lodf[monitored, outage] * isf[outage, bus]))
                    flow_expr = AffExpr(0.0)
                    lodf_coef = lodf[monitored_line.offset, outage_line.offset]

                    for bus in buses
                        bus.offset > 0 || continue

                        # Base ISF term
                        isf_mon = isf[monitored_line.offset, bus.offset]

                        # Combined coefficient with LODF correction
                        total_coef = isf_mon
                        if lodf_coef != 0.0
                            isf_out = isf[outage_line.offset, bus.offset]
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

                    eq_flow_cont_def[
                        sc.name,
                        cont.name,
                        monitored_line.name,
                        t,
                    ] = @constraint(
                        model,
                        flow_cont[sc.name, cont.name, monitored_line.name, t] == flow_expr
                    )

                    # Emergency flow limits (contingency uses emergency_flow_limit, same overflow variable)
                    eq_flow_cont_limit_ub[
                        sc.name,
                        cont.name,
                        monitored_line.name,
                        t,
                    ] = @constraint(
                        model,
                        flow_cont[sc.name, cont.name, monitored_line.name, t] <=
                        monitored_line.emergency_flow_limit[t] +
                        overflow[sc.name, monitored_line.name, t]
                    )
                    eq_flow_cont_limit_lb[
                        sc.name,
                        cont.name,
                        monitored_line.name,
                        t,
                    ] = @constraint(
                        model,
                        flow_cont[sc.name, cont.name, monitored_line.name, t] >=
                        -monitored_line.emergency_flow_limit[t] -
                        overflow[sc.name, monitored_line.name, t]
                    )
                end
            end
        end
    end
    return
end
