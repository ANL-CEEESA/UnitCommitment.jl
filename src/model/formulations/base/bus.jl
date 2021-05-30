# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

function _add_bus!(model::JuMP.Model, b::Bus)::Nothing
    net_injection = _init(model, :expr_net_injection)
    reserve = _init(model, :expr_reserve)
    curtail = _init(model, :curtail)
    for t in 1:model[:instance].time
        # Fixed load
        net_injection[b.name, t] = AffExpr(-b.load[t])

        # Reserves
        reserve[b.name, t] = AffExpr()

        # Load curtailment
        curtail[b.name, t] =
            @variable(model, lower_bound = 0, upper_bound = b.load[t])

        add_to_expression!(net_injection[b.name, t], curtail[b.name, t], 1.0)
        add_to_expression!(
            model[:obj],
            curtail[b.name, t],
            model[:instance].power_balance_penalty[t],
        )
    end
    return
end
