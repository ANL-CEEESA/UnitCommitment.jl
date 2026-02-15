# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

function read_json(
    json::AbstractDict,
    sc::UnitCommitmentScenario,
    ext::ShiftFactorsTransmissionExt,
)
    # Reuse PhaseAngleTransmissionExt reader to read transmission data
    read_json(json, sc, PhaseAngleTransmissionExt())

    # Check for investment lines (not supported)
    for line in sc[:lines]
        if line.invest[1] > 0.0
            error(
                "ShiftFactorsTransmissionExt does not support transmission line investment. " *
                "Line '$(line.name)' has investment cost $(line.invest[1]). " *
                "Use PhaseAngleTransmissionExt instead.",
            )
        end
    end

    # Only single-line contingencies are supported
    for cont in sc[:contingencies]
        length(cont.lines) == 1 || error(
            "ShiftFactorsTransmissionExt only supports contingencies with exactly one " *
            "outage line. Contingency '$(cont.name)' has $(length(cont.lines)) lines.",
        )
    end

    # Compute ISF and LODF matrices
    if length(sc[:lines]) > 0
        isf = _injection_shift_factors(buses = sc[:bus], lines = sc[:lines])
        lodf = _line_outage_factors(
            buses = sc[:bus],
            lines = sc[:lines],
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
