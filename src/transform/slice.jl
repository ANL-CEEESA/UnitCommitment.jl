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
        for u in sc.thermal_units
            u.max_power = u.max_power[range]
            u.min_power = u.min_power[range]
            u.must_run = u.must_run[range]
            u.min_power_cost = u.min_power_cost[range]
            for s in u.cost_segments
                s.mw = s.mw[range]
                s.cost = s.cost[range]
            end
        end
        for pu in sc.profiled_units
            pu.max_power = pu.max_power[range]
            pu.min_power = pu.min_power[range]
            pu.cost = pu.cost[range]
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
        for su in sc.storage_units
            su.min_level = su.min_level[range]
            su.max_level = su.max_level[range]
            su.simultaneous_charge_and_discharge =
                su.simultaneous_charge_and_discharge[range]
            su.charge_cost = su.charge_cost[range]
            su.discharge_cost = su.discharge_cost[range]
            su.charge_efficiency = su.charge_efficiency[range]
            su.discharge_efficiency = su.discharge_efficiency[range]
            su.loss_factor = su.loss_factor[range]
            su.min_charge_rate = su.min_charge_rate[range]
            su.max_charge_rate = su.max_charge_rate[range]
            su.min_discharge_rate = su.min_discharge_rate[range]
            su.max_discharge_rate = su.max_discharge_rate[range]
        end
        for ifc in sc.interfaces
            ifc.net_flow_upper_limit = ifc.net_flow_upper_limit[range]
            ifc.net_flow_lower_limit = ifc.net_flow_lower_limit[range]
            ifc.flow_limit_penalty = ifc.flow_limit_penalty[range]
        end
    end
    return modified
end
