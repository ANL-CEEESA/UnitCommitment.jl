# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

function _add_system_wide_eqs!(model::JuMP.Model)::Nothing
    _add_net_injection_eqs!(model)
    _add_reserve_eqs!(model)
    return
end

function _add_net_injection_eqs!(model::JuMP.Model)::Nothing
    T = model[:instance].time
    net_injection = _init(model, :net_injection)
    eq_net_injection = _init(model, :eq_net_injection)
    eq_power_balance = _init(model, :eq_power_balance)
    for t in 1:T, b in model[:instance].buses
        n = net_injection[b.name, t] = @variable(model)
        eq_net_injection[b.name, t] =
            @constraint(model, -n + model[:expr_net_injection][b.name, t] == 0)
    end
    for t in 1:T
        eq_power_balance[t] = @constraint(
            model,
            sum(net_injection[b.name, t] for b in model[:instance].buses) == 0
        )
    end
    return
end

function _add_reserve_eqs!(model::JuMP.Model)::Nothing
    eq_min_reserve = _init(model, :eq_min_reserve)
    for t in 1:model[:instance].time
        eq_min_reserve[t] = @constraint(
            model,
            sum(
                model[:expr_reserve][b.name, t] for b in model[:instance].buses
            ) >= model[:instance].reserves.spinning[t]
        )
    end
    return
end
