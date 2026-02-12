# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using UnitCommitment

@testfunction components_flexiramp_read_test begin
    instance = UnitCommitment.read(
        fixture("case14/flex.json"),
        extensions = [UnitCommitment.WanHob2016.FlexirampExt()],
    )
    sc = instance.scenarios[1]

    @test haskey(sc, :flexiramp_reserves)
    @test length(sc[:flexiramp_reserves]) == 2

    r1 = sc[:flexiramp_reserves_by_name]["r1"]
    @test r1.name == "r1"
    @test r1.amount ≈ [20.31042, 23.65273, 27.41784, 25.34057]
    @test r1.shortfall_penalty == 5000.0
    @test length(r1.thermal_units) == 2
    @test r1.thermal_units[1].name == "g2"
    @test r1.thermal_units[2].name == "g3"

    r2 = sc[:flexiramp_reserves_by_name]["r2"]
    @test r2.name == "r2"
    @test r2.amount ≈ [15.0, 18.0, 20.0, 17.0]
    @test r2.shortfall_penalty == -1
    @test length(r2.thermal_units) == 2
    @test r2.thermal_units[1].name == "g3"
    @test r2.thermal_units[2].name == "g4"

    @test haskey(sc, :flexiramp_reserves_by_name)
    @test sc[:flexiramp_reserves_by_name]["r1"].name == "r1"
    @test sc[:flexiramp_reserves_by_name]["r2"].name == "r2"

    # Spinning reserves should not include r1/r2 (they're flexiramp, not spinning)
    @test length(sc[:reserves]) == 0
end
