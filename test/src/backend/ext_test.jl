# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

@testfunction backend_ext_parse_extensions_test begin
    exts = UnitCommitment._parse_extensions([
        Dict("type" => "CopperPlateTransmissionExt"),
        Dict("type" => "ShiftFactorsTransmissionExt", "isf_cutoff" => 0.075),
    ],)
    @test length(exts) == 2
    @test exts[1] isa UnitCommitment.CopperPlateTransmissionExt
    @test exts[2] isa UnitCommitment.ShiftFactorsTransmissionExt
    @test exts[2].isf_cutoff == 0.075

    # Nested extensions
    exts = UnitCommitment._parse_extensions([
        Dict(
            "type" => "ThermalExt",
            "pwl_costs" => Dict("type" => "KnuOstWat2018.PwlCosts"),
            "ramping" => Dict("type" => "MorLatRam2013.Ramping"),
            "slimits" =>
                Dict("type" => "MorLatRam2013.StartupShutdownLimits"),
        ),
    ])
    @test length(exts) == 1
    @test exts[1] isa UnitCommitment.ThermalExt
    @test exts[1].pwl_costs isa UnitCommitment.KnuOstWat2018.PwlCosts
    @test exts[1].ramping isa UnitCommitment.MorLatRam2013.Ramping
    @test exts[1].slimits isa UnitCommitment.MorLatRam2013.StartupShutdownLimits

    # Empty list
    exts = UnitCommitment._parse_extensions([])
    @test isempty(exts)
end
