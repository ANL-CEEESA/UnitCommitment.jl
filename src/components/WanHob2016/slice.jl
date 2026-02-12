# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

function slice!(
    sc::UnitCommitmentScenario,
    range::UnitRange{Int},
    ::WanHob2016.FlexirampExt,
)::Nothing
    haskey(sc, :flexiramp_reserves) || return
    for r in sc[:flexiramp_reserves]
        r.amount = r.amount[range]
    end
    return
end
