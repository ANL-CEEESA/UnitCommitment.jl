# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

function slice!(
    sc::UnitCommitmentScenario,
    range::UnitRange{Int},
    ::PhaseAngleTransmissionExt,
)::Nothing
    for l in sc[:branches]
        l.normal_flow_limit = l.normal_flow_limit[range]
        l.emergency_flow_limit = l.emergency_flow_limit[range]
        l.flow_limit_penalty = l.flow_limit_penalty[range]
        l.invest = l.invest[range]
    end
    return
end
