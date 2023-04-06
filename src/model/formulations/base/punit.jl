# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

function _add_profiled_unit!(
    model::JuMP.Model,
    pu::ProfiledUnit,
    sc::UnitCommitmentScenario,
)::Nothing
    punits = _init(model, :prod_profiled)
    net_injection = _init(model, :expr_net_injection)
    for t in 1:model[:instance].time
        # Decision variable
        punits[sc.name, pu.name, t] =
            @variable(model, lower_bound = 0, upper_bound = pu.capacity[t])

        # Objective function terms
        add_to_expression!(
            model[:obj],
            punits[sc.name, pu.name, t],
            pu.cost[t] * sc.probability,
        )

        # Net injection
        add_to_expression!(
            net_injection[sc.name, pu.bus.name, t],
            punits[sc.name, pu.name, t],
            1.0,
        )
    end
    return
end
