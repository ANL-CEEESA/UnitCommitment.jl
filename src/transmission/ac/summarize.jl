# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

function summarize(
    instance::UnitCommitmentInstance,
    ::ACTransmissionExt,
    io::IO,
)::Nothing
    sc = instance.scenarios[1]
    print(io, "$(length(sc[:branches])) branches, ")
    print(io, "$(length(sc[:shunts])) shunt devices, ")
    return
end
