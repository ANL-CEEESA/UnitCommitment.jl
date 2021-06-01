# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using UnitCommitment, LinearAlgebra, Cbc, JuMP, JSON, GZip

@testset "read_benchmark" begin
    instance = UnitCommitment.read_benchmark("test/case14")

    @test length(instance.lines) == 20
    @test length(instance.buses) == 14
    @test length(instance.units) == 6
    @test length(instance.contingencies) == 19
    @test length(instance.price_sensitive_loads) == 1
    @test instance.time == 4

    @test instance.lines[5].name == "l5"
    @test instance.lines[5].source.name == "b2"
    @test instance.lines[5].target.name == "b5"
    @test instance.lines[5].reactance ≈ 0.17388
    @test instance.lines[5].susceptance ≈ 10.037550333
    @test instance.lines[5].normal_flow_limit == [1e8 for t in 1:4]
    @test instance.lines[5].emergency_flow_limit == [1e8 for t in 1:4]
    @test instance.lines[5].flow_limit_penalty == [5e3 for t in 1:4]

    @test instance.lines[1].name == "l1"
    @test instance.lines[1].source.name == "b1"
    @test instance.lines[1].target.name == "b2"
    @test instance.lines[1].reactance ≈ 0.059170
    @test instance.lines[1].susceptance ≈ 29.496860773945
    @test instance.lines[1].normal_flow_limit == [300.0 for t in 1:4]
    @test instance.lines[1].emergency_flow_limit == [400.0 for t in 1:4]
    @test instance.lines[1].flow_limit_penalty == [1e3 for t in 1:4]

    @test instance.buses[9].name == "b9"
    @test instance.buses[9].load == [35.36638, 33.25495, 31.67138, 31.14353]

    unit = instance.units[1]
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
    @test unit.provides_spinning_reserves == [true for t in 1:4]
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

    unit = instance.units[2]
    @test unit.name == "g2"
    @test unit.must_run == [false for t in 1:4]

    unit = instance.units[3]
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
    @test unit.provides_spinning_reserves == [true for t in 1:4]
    for t in 1:4
        @test unit.cost_segments[1].mw[t] ≈ 33
        @test unit.cost_segments[2].mw[t] ≈ 33
        @test unit.cost_segments[3].mw[t] ≈ 34
        @test unit.cost_segments[1].cost[t] ≈ 33.75
        @test unit.cost_segments[2].cost[t] ≈ 38.04
        @test unit.cost_segments[3].cost[t] ≈ 44.77853
    end

    @test instance.reserves.spinning == zeros(4)

    @test instance.contingencies[1].lines == [instance.lines[1]]
    @test instance.contingencies[1].units == []

    load = instance.price_sensitive_loads[1]
    @test load.name == "ps1"
    @test load.bus.name == "b3"
    @test load.revenue == [100.0 for t in 1:4]
    @test load.demand == [50.0 for t in 1:4]
end

@testset "read_benchmark sub-hourly" begin
    instance = UnitCommitment.read_benchmark("test/case14-sub-hourly")
    @test instance.time == 4
    unit = instance.units[1]
    @test unit.name == "g1"
    @test unit.min_uptime == 2
    @test unit.min_downtime == 2
    @test length(unit.startup_categories) == 3
    @test unit.startup_categories[1].delay == 2
    @test unit.startup_categories[2].delay == 4
    @test unit.startup_categories[3].delay == 6
    @test unit.initial_status == -200
end
