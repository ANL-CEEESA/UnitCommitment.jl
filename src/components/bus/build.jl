# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

function _add_buses!(
    model::JuMP.Model,
    instance::UnitCommitmentInstance,
)::Nothing
    _add_bus_vars!(model, instance)
    _add_bus_obj!(model, instance)
    _add_bus_constrs!(model, instance)
    return
end

function _add_bus_vars!(
    model::JuMP.Model,
    instance::UnitCommitmentInstance,
)::Nothing
    T = instance.time
    curtail = _init(model, :curtail)
    reactive_curtail = _init(model, :reactive_curtail)

    for sc in instance.scenarios, b in sc[:bus]
        for t in 1:T
            curtail[sc.name, b.name, t] = @variable(
                model,
                lower_bound = min(0, b.load[t]),
                upper_bound = max(0, b.load[t]),
            )
            reactive_curtail[sc.name, b.name, t] = @variable(
                model,
                lower_bound = min(0, b.reactive_load[t]),
                upper_bound = max(0, b.reactive_load[t]),
            )
        end
    end
    return
end

function _add_bus_obj!(
    model::JuMP.Model,
    instance::UnitCommitmentInstance,
)::Nothing
    T = instance.time
    curtail = model[:curtail]
    reactive_curtail = model[:reactive_curtail]

    for t in 1:T, sc in instance.scenarios, b in sc[:bus]
        sign_adjustment = b.load[t] < 0 ? -1 : 1
        add_to_expression!(
            model[:obj],
            curtail[sc.name, b.name, t],
            sc[:power_balance_penalty][t] * sc[:probability] * sign_adjustment,
        )
        reactive_sign_adjustment = b.reactive_load[t] < 0 ? -1 : 1
        add_to_expression!(
            model[:obj],
            reactive_curtail[sc.name, b.name, t],
            sc[:power_balance_penalty][t] *
            sc[:probability] *
            reactive_sign_adjustment,
        )
    end
    return
end

function _add_bus_constrs!(
    model::JuMP.Model,
    instance::UnitCommitmentInstance,
)::Nothing
    T = instance.time
    eq_net_injection = _init(model, :eq_net_injection)
    eq_net_reactive_injection = _init(model, :eq_net_reactive_injection)
    ni = model[:ni]
    qi = model[:qi]
    curtail = model[:curtail]
    reactive_curtail = model[:reactive_curtail]

    for sc in instance.scenarios
        for t in 1:T
            for b in sc[:bus]
                # Net injection definition. Necessary for LMP calculation and model customization.
                eq_net_injection[sc.name, b.name, t] = @constraint(
                    model,
                    ni[sc.name, b.name, t] ==
                    model[:net_injection][sc.name, b.name, t] +
                    curtail[sc.name, b.name, t],
                )

                # Net reactive injection definition.
                eq_net_reactive_injection[sc.name, b.name, t] = @constraint(
                    model,
                    qi[sc.name, b.name, t] ==
                    model[:net_reactive_injection][sc.name, b.name, t] +
                    reactive_curtail[sc.name, b.name, t],
                )
            end
        end
    end
    return
end
