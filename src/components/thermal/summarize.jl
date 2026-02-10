# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

function summarize(
    instance::UnitCommitmentInstance,
    ::ThermalExt,
    io::IO,
)::Nothing
    count = length(instance.scenarios[1][:thermal])
    print(io, "$count thermal units, ")
    return
end
