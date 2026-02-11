# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using UnitCommitment

@testfunction components_profiled_read_test begin
    instance = UnitCommitment.read(fixture("case14-profiled.json.gz"))
    sc = instance.scenarios[1]
    @test length(sc[:profiled]) == 2

    pu1 = sc[:profiled][1]
    @test pu1.name == "g7"
    @test pu1.bus.name == "b4"
    @test pu1.cost == [100.0 for t in 1:4]
    @test pu1.min_power == [60.0 for t in 1:4]
    @test pu1.max_power == [100.0 for t in 1:4]
    @test sc[:profiled_by_name]["g7"].name == "g7"

    pu2 = sc[:profiled][2]
    @test pu2.name == "g8"
    @test pu2.bus.name == "b5"
    @test pu2.cost == [50.0 for t in 1:4]
    @test pu2.min_power == [0.0 for t in 1:4]
    @test pu2.max_power == [120.0 for t in 1:4]
    @test sc[:profiled_by_name]["g8"].name == "g8"
end
