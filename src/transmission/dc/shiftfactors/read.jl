# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

function read_json(
    json::AbstractDict,
    sc::UnitCommitmentScenario,
    ext::ShiftFactorsTransmissionExt,
)
    read_json(json, sc, CopperPlateTransmissionExt())

    # Compute ISF and LODF matrices
    if length(sc[:branches]) > 0
        isf =
            _injection_shift_factors(buses = sc[:bus], branches = sc[:branches])
        lodf = _line_outage_factors(
            buses = sc[:bus],
            branches = sc[:branches],
            isf = isf,
        )

        # Apply cutoffs to reduce matrix density
        isf[abs.(isf).<ext.isf_cutoff] .= 0.0
        lodf[abs.(lodf).<ext.lodf_cutoff] .= 0.0

        sc[:isf] = isf
        sc[:lodf] = lodf
    end

    return
end
