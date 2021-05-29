# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

function _add_transmission_line!(model, lm)::Nothing
    overflow = _get(model, :overflow)
    for t in 1:model[:instance].time
        v = overflow[lm.name, t] = @variable(model, lower_bound = 0)
        add_to_expression!(model[:obj], v, lm.flow_limit_penalty[t])
    end
    return
end
