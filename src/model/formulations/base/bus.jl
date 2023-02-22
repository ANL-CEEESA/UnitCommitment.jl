# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

function _add_bus!(
    model::JuMP.Model,
    b::Bus,
    sc::UnitCommitmentScenario,
)::Nothing
    net_injection = _init(model, :expr_net_injection)
    curtail = _init(model, :curtail)
    for t in 1:model[:instance].time
        # Fixed load
        net_injection[sc.name, b.name, t] = AffExpr(-b.load[t])

        # Load curtailment
        curtail[sc.name, b.name, t] =
            @variable(model, lower_bound = 0, upper_bound = b.load[t])

        add_to_expression!(
            net_injection[sc.name, b.name, t],
            curtail[sc.name, b.name, t],
            1.0,
        )
        add_to_expression!(
            model[:obj],
            curtail[sc.name, b.name, t],
            sc.power_balance_penalty[t] * sc.probability,
        )
    end
    return
end
