# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

"""
    slice(instance, range)

Creates a new instance, with only a subset of the time periods.
This function does not modify the provided instance. The initial
conditions are also not modified.

Example
-------

```julia
# Build a 2-hour UC instance
instance = UnitCommitment.read_benchmark("matpower/case118/2017-02-01")
modified = UnitCommitment.slice(instance, 1:2)
```
"""
function slice(
    instance::UnitCommitmentInstance,
    range::UnitRange{Int},
)::UnitCommitmentInstance
    modified = deepcopy(instance)
    modified.time = length(range)
    for sc in modified.scenarios
        sc.power_balance_penalty = sc.power_balance_penalty[range]
        for r in sc.reserves
            r.amount = r.amount[range]
        end
        for u in sc.units
            u.max_power = u.max_power[range]
            u.min_power = u.min_power[range]
            u.must_run = u.must_run[range]
            u.min_power_cost = u.min_power_cost[range]
            for s in u.cost_segments
                s.mw = s.mw[range]
                s.cost = s.cost[range]
            end
        end
        for b in sc.buses
            b.load = b.load[range]
        end
        for l in sc.lines
            l.normal_flow_limit = l.normal_flow_limit[range]
            l.emergency_flow_limit = l.emergency_flow_limit[range]
            l.flow_limit_penalty = l.flow_limit_penalty[range]
        end
        for ps in sc.price_sensitive_loads
            ps.demand = ps.demand[range]
            ps.revenue = ps.revenue[range]
        end
    end
    return modified
end
