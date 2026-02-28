# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using UnitCommitment

const _PA_EXTENSIONS =
    [UnitCommitment.PhaseAngleTransmissionExt(), UnitCommitment.NoLMP()]

@testfunction transmission_dc_phaseangle_powermodels_case5_test begin
    _validate_dc_opf("case5", extensions = _PA_EXTENSIONS, check_angles = true)
end

@testfunction transmission_dc_phaseangle_powermodels_case5_gs_test begin
    _validate_dc_opf(
        "case5_gs",
        extensions = _PA_EXTENSIONS,
        check_angles = true,
    )
end

@testfunction transmission_dc_phaseangle_powermodels_case14_test begin
    _validate_dc_opf(
        "case14_pwl",
        extensions = _PA_EXTENSIONS,
        check_angles = true,
    )
end

@testfunction transmission_dc_phaseangle_powermodels_case5_strg_test begin
    _validate_dc_opf(
        "case5_strg",
        extensions = _PA_EXTENSIONS,
        check_angles = true,
        multinetwork = true,
        optimizer = _minlp_optimizer(),
    )
end

# case5_pwlc: Skipped — DC lines not supported in UC.jl conversion
