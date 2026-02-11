# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using UnitCommitment

@testfunction components_thermal_read_test begin
    instance = UnitCommitment.read(fixture("case14/base.json"))
    sc = instance.scenarios[1]

    @test length(sc[:thermal]) == 6
    @test length(sc[:reserves]) == 1

    # Reserves
    @test sc[:reserves][1].name == "r1"
    @test sc[:reserves][1].amount == [100.0, 100.0, 100.0, 100.0]
    @test sc[:reserves_by_name]["r1"].name == "r1"

    # Unit g1
    unit = sc[:thermal][1]
    @test unit.name == "g1"
    @test unit.bus.name == "b1"
    @test unit.ramp_up_limit == 1e6
    @test unit.ramp_down_limit == 1e6
    @test unit.startup_limit == 1e6
    @test unit.shutdown_limit == 1e6
    @test unit.must_run == [false for t in 1:4]
    @test unit.min_power_cost == [1400.0 for t in 1:4]
    @test unit.min_uptime == 1
    @test unit.min_downtime == 1
    for t in 1:1
        @test unit.cost_segments[1].mw[t] == 10.0
        @test unit.cost_segments[2].mw[t] == 20.0
        @test unit.cost_segments[3].mw[t] == 5.0
        @test unit.cost_segments[1].cost[t] ≈ 20.0
        @test unit.cost_segments[2].cost[t] ≈ 30.0
        @test unit.cost_segments[3].cost[t] ≈ 40.0
    end
    @test length(unit.startup_categories) == 3
    @test unit.startup_categories[1].delay == 1
    @test unit.startup_categories[2].delay == 2
    @test unit.startup_categories[3].delay == 3
    @test unit.startup_categories[1].cost == 1000.0
    @test unit.startup_categories[2].cost == 1500.0
    @test unit.startup_categories[3].cost == 2000.0
    @test length(unit.reserves) == 0
    @test sc[:thermal_by_name]["g1"].name == "g1"

    # Unit g2
    unit = sc[:thermal][2]
    @test unit.name == "g2"
    @test unit.must_run == [false for t in 1:4]
    @test length(unit.reserves) == 1

    # Unit g3
    unit = sc[:thermal][3]
    @test unit.name == "g3"
    @test unit.bus.name == "b3"
    @test unit.ramp_up_limit == 70.0
    @test unit.ramp_down_limit == 70.0
    @test unit.startup_limit == 70.0
    @test unit.shutdown_limit == 70.0
    @test unit.must_run == [true for t in 1:4]
    @test unit.min_power_cost == [0.0 for t in 1:4]
    @test unit.min_uptime == 1
    @test unit.min_downtime == 1
    for t in 1:4
        @test unit.cost_segments[1].mw[t] ≈ 33
        @test unit.cost_segments[2].mw[t] ≈ 33
        @test unit.cost_segments[3].mw[t] ≈ 34
        @test unit.cost_segments[1].cost[t] ≈ 33.75
        @test unit.cost_segments[2].cost[t] ≈ 38.04
        @test unit.cost_segments[3].cost[t] ≈ 44.77853
    end
    @test length(unit.reserves) == 1
    @test unit.reserves[1].name == "r1"
end

@testfunction components_thermal_read_sub_hourly_test begin
    instance = UnitCommitment.read(fixture("case14-sub-hourly.json.gz"))
    unit = instance.scenarios[1][:thermal][1]
    @test unit.name == "g1"
    @test unit.min_uptime == 2
    @test unit.min_downtime == 2
    @test length(unit.startup_categories) == 3
    @test unit.startup_categories[1].delay == 2
    @test unit.startup_categories[2].delay == 4
    @test unit.startup_categories[3].delay == 6
    @test unit.initial_status == -200
end

@testfunction components_thermal_read_commitment_status_test begin
    instance = UnitCommitment.read(fixture("case14-fixed-status.json.gz"))
    sc = instance.scenarios[1]

    @test sc[:thermal][1].commitment_status == [nothing for t in 1:4]
    @test sc[:thermal][2].commitment_status == [true for t in 1:4]
    @test sc[:thermal][4].commitment_status == [false for t in 1:4]
    @test sc[:thermal][6].commitment_status == [false, nothing, true, nothing]
end
