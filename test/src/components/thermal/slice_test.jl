# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using UnitCommitment

@testfunction components_thermal_slice_test begin
    instance = UnitCommitment.read(fixture("case14.json.gz"))
    modified = UnitCommitment.slice(instance, 1:2)
    sc = modified.scenarios[1]

    # g1: has cost segments, non-zero min_power
    g1 = sc[:thermal_by_name]["g1"]
    @test g1.max_power == [135.0, 135.0]
    @test g1.min_power == [100.0, 100.0]
    @test g1.must_run == [false, false]
    @test g1.min_power_cost == [1400.0, 1400.0]
    @test g1.cost_segments[1].mw == [10.0, 10.0]
    @test g1.cost_segments[1].cost == [20.0, 20.0]
    @test g1.cost_segments[2].mw == [20.0, 20.0]
    @test g1.cost_segments[2].cost == [30.0, 30.0]
    @test g1.cost_segments[3].mw == [5.0, 5.0]
    @test g1.cost_segments[3].cost == [40.0, 40.0]

    # g3
    g3 = sc[:thermal_by_name]["g3"]
    @test g3.must_run == [false, false]
    @test g3.min_power == [0.0, 0.0]
    @test g3.max_power == [100.0, 100.0]

    # g6: min_power=max_power, no cost segments
    g6 = sc[:thermal_by_name]["g6"]
    @test g6.max_power == [100.0, 100.0]
    @test g6.min_power == [100.0, 100.0]
    @test g6.min_power_cost == [10000.0, 10000.0]

    # Reserves
    r1 = sc[:reserves_by_name]["r1"]
    @test r1.amount == [100.0, 100.0]
end
