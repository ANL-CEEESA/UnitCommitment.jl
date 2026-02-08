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
    ni = _init(model, :ni)

    for sc in instance.scenarios, b in sc.buses
        for t in 1:T
            # Fixed load
            add_to_expression!(
                model[:net_injection][sc.name, b.name, t],
                -b.load[t],
            )

            # Load curtailment
            curtail[sc.name, b.name, t] = @variable(
                model,
                lower_bound = min(0, b.load[t]),
                upper_bound = max(0, b.load[t]),
            )
            add_to_expression!(
                model[:net_injection][sc.name, b.name, t],
                curtail[sc.name, b.name, t],
                1.0,
            )

            # Net injection variable
            ni[sc.name, b.name, t] = @variable(model)
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

    for t in 1:T, sc in instance.scenarios, b in sc.buses
        sign_adjustment = b.load[t] < 0 ? -1 : 1
        add_to_expression!(
            model[:obj],
            curtail[sc.name, b.name, t],
            sc.power_balance_penalty[t] * sc.probability * sign_adjustment,
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
    eq_power_balance = _init(model, :eq_power_balance)
    ni = model[:ni]

    for sc in instance.scenarios
        for t in 1:T
            # Net injection definition. Necessary for LMP calculation and model customization.
            for b in sc.buses
                eq_net_injection[sc.name, b.name, t] = @constraint(
                    model,
                    -ni[sc.name, b.name, t] + model[:net_injection][sc.name, b.name, t] == 0,
                )
            end

            # System-wide power balance
            eq_power_balance[sc.name, t] = @constraint(
                model,
                sum(
                    ni[sc.name, b.name, t] for b in sc.buses
                ) == 0,
            )
        end
    end
    return
end
