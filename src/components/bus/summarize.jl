# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

function summarize_buses(instance::UnitCommitmentInstance, io::IO)::Nothing
    count = length(instance.scenarios[1][:bus])
    print(io, "$count buses, ")
    return
end
