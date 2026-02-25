# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

function _compute_base_flow(
    model::UnitCommitmentModel,
    sc::UnitCommitmentScenario,
    ::PhaseAngleTransmissionExt,
)
    T = model.instance.time
    branches = sc[:branches]
    L = length(branches)
    flow_var = model.inner[:flow]
    pre_flow = zeros(L, T)
    for b in branches, t in 1:T
        pre_flow[b.offset, t] = value(flow_var[sc.name, b.name, t])
    end
    return pre_flow
end

function _compute_contingency_flow(
    ::UnitCommitmentModel,
    ::UnitCommitmentScenario,
    ::Matrix{Float64},
    ::PhaseAngleTransmissionExt,
)
    return error("PhaseAngleTransmissionExt does not support contingencies")
end
