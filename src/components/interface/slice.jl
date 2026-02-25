# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

function slice!(
    sc::UnitCommitmentScenario,
    range::UnitRange{Int},
    ::InterfaceLimitsExt,
)::Nothing
    for ifc in sc[:interfaces]
        ifc.net_flow_ub = ifc.net_flow_ub[range]
        ifc.net_flow_lb = ifc.net_flow_lb[range]
        ifc.flow_limit_penalty = ifc.flow_limit_penalty[range]
    end
    return nothing
end
