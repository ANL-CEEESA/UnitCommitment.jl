# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

function slice!(
    sc::UnitCommitmentScenario,
    range::UnitRange{Int},
    ::ShiftFactorsTransmissionExt,
)::Nothing
    # Delegate transmission line slicing to PhaseAngleTransmissionExt
    # ISF and LODF matrices are time-invariant, so no slicing needed
    slice!(sc, range, PhaseAngleTransmissionExt())
    return
end
