# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using UnitCommitment

@testfunction components_psload_read_test begin
    instance = UnitCommitment.read(fixture("case14/base.json"))
    sc = instance.scenarios[1]
    @test length(sc[:psload]) == 1
    load = sc[:psload][1]
    @test load.name == "ps1"
    @test load.bus.name == "b3"
    @test load.revenue == [100.0 for t in 1:4]
    @test load.demand == [50.0 for t in 1:4]
    @test sc[:psload_by_name]["ps1"].name == "ps1"
end
