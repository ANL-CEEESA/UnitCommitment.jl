# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

function summarize(
    instance::UnitCommitmentInstance,
    ::WanHob2016.FlexirampExt,
    io::IO,
)::Nothing
    haskey(instance.scenarios[1], :flexiramp_reserves) || return
    count = length(instance.scenarios[1][:flexiramp_reserves])
    print(io, "$count flexiramp reserves, ")
    return
end
