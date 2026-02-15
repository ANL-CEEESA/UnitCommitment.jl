# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

function summarize(
    instance::UnitCommitmentInstance,
    ::TransmissionExtension,
    io::IO,
)::Nothing
    sc = instance.scenarios[1]
    print(io, "$(length(sc[:branches])) branches, ")
    if !isempty(sc[:contingencies])
        print(io, "$(length(sc[:contingencies])) contingencies, ")
    end
    if !isempty(sc[:shunts])
        print(io, "$(length(sc[:shunts])) shunt devices, ")
    end
    return
end
