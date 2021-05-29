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

    # Build a 2-hour UC instance
    instance = UnitCommitment.read_benchmark("test/case14")
    modified = UnitCommitment.slice(instance, 1:2)

"""
function slice(
    instance::UnitCommitmentInstance,
    range::UnitRange{Int},
)::UnitCommitmentInstance
    modified = deepcopy(instance)
    modified.time = length(range)
    modified.power_balance_penalty = modified.power_balance_penalty[range]
    modified.reserves.spinning = modified.reserves.spinning[range]
    for u in modified.units
        u.max_power = u.max_power[range]
        u.min_power = u.min_power[range]
        u.must_run = u.must_run[range]
        u.min_power_cost = u.min_power_cost[range]
        u.provides_spinning_reserves = u.provides_spinning_reserves[range]
        for s in u.cost_segments
            s.mw = s.mw[range]
            s.cost = s.cost[range]
        end
    end
    for b in modified.buses
        b.load = b.load[range]
    end
    for l in modified.lines
        l.normal_flow_limit = l.normal_flow_limit[range]
        l.emergency_flow_limit = l.emergency_flow_limit[range]
        l.flow_limit_penalty = l.flow_limit_penalty[range]
    end
    for ps in modified.price_sensitive_loads
        ps.demand = ps.demand[range]
        ps.revenue = ps.revenue[range]
    end
    return modified
end
