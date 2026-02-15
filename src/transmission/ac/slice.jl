# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

function slice!(
    sc::UnitCommitmentScenario,
    range::UnitRange{Int},
    ::ACTransmissionExt,
)::Nothing
    for l in sc[:branches]
        l.normal_flow_limit = l.normal_flow_limit[range]
        l.emergency_flow_limit = l.emergency_flow_limit[range]
        l.flow_limit_penalty = l.flow_limit_penalty[range]
    end
    for sh in sc[:shunts]
        sh.status = sh.status[range]
    end
    return
end
