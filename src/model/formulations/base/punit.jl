# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

function _add_profiled_unit!(
    model::JuMP.Model,
    pu::ProfiledUnit,
)::Nothing
    punits = _init(model, :profiled_units)
    net_injection = _init(model, :expr_net_injection)
    for t in 1:model[:instance].time
        # Decision variable
        punits[pu.name, t] =
            @variable(model, lower_bound = 0, upper_bound = pu.capacity[t])

        # Objective function terms
        add_to_expression!(model[:obj], punits[pu.name, t], pu.cost[t])

        # Net injection
        add_to_expression!(
            net_injection[pu.bus.name, t],
            punits[pu.name, t],
            1.0,
        )
    end
    return
end
