# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using UnitCommitment

@testfunction transmission_dc_shiftfactors_investment_error_test begin
    @test_throws ErrorException UnitCommitment.read(
        fixture("tep_ieee24.json.gz"),
        extensions = [UnitCommitment.ShiftFactorsTransmissionExt()],
    )
end

@testfunction transmission_dc_shiftfactors_multi_outage_error_test begin
    @test_throws ErrorException UnitCommitment.read(
        fixture("case5/multi_outage.json"),
        extensions = [UnitCommitment.ShiftFactorsTransmissionExt()],
    )
end
