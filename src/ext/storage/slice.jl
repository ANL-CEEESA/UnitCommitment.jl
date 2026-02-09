# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

function slice!(
    sc::UnitCommitmentScenario,
    range::UnitRange{Int},
    ::StorageExt,
)::Nothing
    for su in sc.data[:storage]
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
        su.invest = su.invest[range]
    end
    return
end
