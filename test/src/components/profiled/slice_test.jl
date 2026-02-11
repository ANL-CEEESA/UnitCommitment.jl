# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using UnitCommitment

@testfunction components_profiled_slice_test begin
    instance = UnitCommitment.read(fixture("case14-profiled.json.gz"))
    modified = UnitCommitment.slice(instance, 1:2)
    sc = modified.scenarios[1]

    g7 = sc[:profiled_by_name]["g7"]
    @test g7.max_power == [100.0, 100.0]
    @test g7.min_power == [60.0, 60.0]
    @test g7.cost == [100.0, 100.0]

    g8 = sc[:profiled_by_name]["g8"]
    @test g8.max_power == [120.0, 120.0]
    @test g8.min_power == [0.0, 0.0]
    @test g8.cost == [50.0, 50.0]
end
