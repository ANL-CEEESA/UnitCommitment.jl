# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

function slice!(
    sc::UnitCommitmentScenario,
    range::UnitRange{Int},
    ::ThermalExt,
)::Nothing
    for r in sc[:reserves]
        r.amount = r.amount[range]
    end
    for u in sc[:thermal]
        u.max_power = u.max_power[range]
        u.min_power = u.min_power[range]
        u.must_run = u.must_run[range]
        u.min_power_cost = u.min_power_cost[range]
        for s in u.cost_segments
            s.mw = s.mw[range]
            s.cost = s.cost[range]
        end
    end
    return
end
