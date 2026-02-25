# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using JuMP

function _interface_flow_expr(
    model::JuMP.Model,
    sc::UnitCommitmentScenario,
    ifc,
    t::Int,
    ext::UnitCommitmentExtension,
)
    return error(
        "_interface_flow_expr not implemented for $(typeof(ext)). " *
        "Custom transmission extensions must implement this method to support interface limits.",
    )
end

function build_model(
    model::JuMP.Model,
    instance::UnitCommitmentInstance,
    ::InterfaceLimitsExt,
)::Nothing
    T = instance.time
    any_interfaces = any(!isempty(sc[:interfaces]) for sc in instance.scenarios)
    any_interfaces || return nothing

    _add_interface_vars!(model, instance)
    _add_interface_obj!(model, instance)
    _add_interface_constrs!(model, instance)
    return nothing
end

function _add_interface_vars!(
    model::JuMP.Model,
    instance::UnitCommitmentInstance,
)::Nothing
    T = instance.time
    interface_flow = _init(model, :interface_flow)
    interface_overflow = _init(model, :interface_overflow)

    for sc in instance.scenarios, ifc in sc[:interfaces], t in 1:T
        interface_flow[sc.name, ifc.name, t] = @variable(model)
        interface_overflow[sc.name, ifc.name, t] =
            @variable(model, lower_bound = 0)
    end
    return nothing
end

function _add_interface_obj!(
    model::JuMP.Model,
    instance::UnitCommitmentInstance,
)::Nothing
    T = instance.time
    interface_overflow = model[:interface_overflow]

    for sc in instance.scenarios, ifc in sc[:interfaces], t in 1:T
        add_to_expression!(
            model[:obj],
            interface_overflow[sc.name, ifc.name, t],
            ifc.flow_limit_penalty[t] * sc[:probability],
        )
    end
    return nothing
end

function _add_interface_constrs!(
    model::JuMP.Model,
    instance::UnitCommitmentInstance,
)::Nothing
    T = instance.time
    interface_flow = model[:interface_flow]
    interface_overflow = model[:interface_overflow]

    eq_interface_flow_def = _init(model, :eq_interface_flow_def)
    eq_interface_flow_ub = _init(model, :eq_interface_flow_ub)
    eq_interface_flow_lb = _init(model, :eq_interface_flow_lb)

    transmission_ext = instance.extension_by_slot[:transmission]

    for sc in instance.scenarios, ifc in sc[:interfaces], t in 1:T
        # Flow definition (dispatched on transmission formulation)
        flow_expr = _interface_flow_expr(model, sc, ifc, t, transmission_ext)

        eq_interface_flow_def[sc.name, ifc.name, t] = @constraint(
            model,
            interface_flow[sc.name, ifc.name, t] == flow_expr
        )

        # Upper bound (skip if non-finite)
        if isfinite(ifc.net_flow_ub[t])
            eq_interface_flow_ub[sc.name, ifc.name, t] = @constraint(
                model,
                interface_flow[sc.name, ifc.name, t] <=
                ifc.net_flow_ub[t] + interface_overflow[sc.name, ifc.name, t]
            )
        end

        # Lower bound (skip if non-finite)
        if isfinite(ifc.net_flow_lb[t])
            eq_interface_flow_lb[sc.name, ifc.name, t] = @constraint(
                model,
                interface_flow[sc.name, ifc.name, t] >=
                ifc.net_flow_lb[t] - interface_overflow[sc.name, ifc.name, t]
            )
        end
    end
    return nothing
end
