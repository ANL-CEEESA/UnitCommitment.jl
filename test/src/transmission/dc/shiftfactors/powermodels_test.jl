# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using UnitCommitment

const _SF_EXTENSIONS = [
    UnitCommitment.ShiftFactorsTransmissionExt(
        isf_cutoff = 0.0,
        lodf_cutoff = 0.0,
        lazy = false,
    ),
    UnitCommitment.NoLMP(),
]

@testfunction transmission_dc_shiftfactors_powermodels_case5_test begin
    _validate_dc_opf("case5", extensions = _SF_EXTENSIONS)
end

@testfunction transmission_dc_shiftfactors_powermodels_case5_gs_test begin
    _validate_dc_opf("case5_gs", extensions = _SF_EXTENSIONS)
end

@testfunction transmission_dc_shiftfactors_powermodels_case14_test begin
    _validate_dc_opf("case14_pwl", extensions = _SF_EXTENSIONS)
end

@testfunction transmission_dc_shiftfactors_powermodels_case5_strg_test begin
    _validate_dc_opf(
        "case5_strg",
        extensions = _SF_EXTENSIONS,
        multinetwork = true,
        optimizer = _minlp_optimizer(),
    )
end
