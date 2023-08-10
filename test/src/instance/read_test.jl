# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using UnitCommitment, LinearAlgebra, Cbc, JuMP, JSON, GZip

function instance_read_test()
    @testset "read_benchmark" begin
        instance = UnitCommitment.read(fixture("case14.json.gz"))

        @test repr(instance) == (
            "UnitCommitmentInstance(1 scenarios, 6 thermal units, 0 profiled units, 14 buses, " *
            "20 lines, 19 contingencies, 1 price sensitive loads, 4 time steps)"
        )

        @test length(instance.scenarios) == 1
        sc = instance.scenarios[1]
        @test length(sc.lines) == 20
        @test length(sc.buses) == 14
        @test length(sc.thermal_units) == 6
        @test length(sc.contingencies) == 19
        @test length(sc.price_sensitive_loads) == 1
        @test instance.time == 4
        @test sc.time_step == 60

        @test sc.lines[5].name == "l5"
        @test sc.lines[5].source.name == "b2"
        @test sc.lines[5].target.name == "b5"
        @test sc.lines[5].susceptance ≈ 10.037550333
        @test sc.lines[5].normal_flow_limit == [1e8 for t in 1:4]
        @test sc.lines[5].emergency_flow_limit == [1e8 for t in 1:4]
        @test sc.lines[5].flow_limit_penalty == [5e3 for t in 1:4]
        @test sc.lines_by_name["l5"].name == "l5"

        @test sc.lines[1].name == "l1"
        @test sc.lines[1].source.name == "b1"
        @test sc.lines[1].target.name == "b2"
        @test sc.lines[1].susceptance ≈ 29.496860773945
        @test sc.lines[1].normal_flow_limit == [300.0 for t in 1:4]
        @test sc.lines[1].emergency_flow_limit == [400.0 for t in 1:4]
        @test sc.lines[1].flow_limit_penalty == [1e3 for t in 1:4]

        @test sc.buses[9].name == "b9"
        @test sc.buses[9].load == [35.36638, 33.25495, 31.67138, 31.14353]
        @test sc.buses_by_name["b9"].name == "b9"

        @test sc.reserves[1].name == "r1"
        @test sc.reserves[1].type == "spinning"
        @test sc.reserves[1].amount == [100.0, 100.0, 100.0, 100.0]
        @test sc.reserves_by_name["r1"].name == "r1"

        unit = sc.thermal_units[1]
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
        @test sc.thermal_units_by_name["g1"].name == "g1"

        unit = sc.thermal_units[2]
        @test unit.name == "g2"
        @test unit.must_run == [false for t in 1:4]
        @test length(unit.reserves) == 1

        unit = sc.thermal_units[3]
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

        @test sc.contingencies[1].lines == [sc.lines[1]]
        @test sc.contingencies[1].thermal_units == []
        @test sc.contingencies[1].name == "c1"
        @test sc.contingencies_by_name["c1"].name == "c1"

        load = sc.price_sensitive_loads[1]
        @test load.name == "ps1"
        @test load.bus.name == "b3"
        @test load.revenue == [100.0 for t in 1:4]
        @test load.demand == [50.0 for t in 1:4]
        @test sc.price_sensitive_loads_by_name["ps1"].name == "ps1"
    end

    @testset "read_benchmark sub-hourly" begin
        instance = UnitCommitment.read(fixture("case14-sub-hourly.json.gz"))
        @test instance.time == 4
        unit = instance.scenarios[1].thermal_units[1]
        @test unit.name == "g1"
        @test unit.min_uptime == 2
        @test unit.min_downtime == 2
        @test length(unit.startup_categories) == 3
        @test unit.startup_categories[1].delay == 2
        @test unit.startup_categories[2].delay == 4
        @test unit.startup_categories[3].delay == 6
        @test unit.initial_status == -200
    end

    @testset "read_benchmark profiled-units" begin
        instance = UnitCommitment.read(fixture("case14-profiled.json.gz"))
        sc = instance.scenarios[1]
        @test length(sc.profiled_units) == 2

        pu1 = sc.profiled_units[1]
        @test pu1.name == "g7"
        @test pu1.bus.name == "b4"
        @test pu1.cost == [100.0 for t in 1:4]
        @test pu1.min_power == [60.0 for t in 1:4]
        @test pu1.max_power == [100.0 for t in 1:4]
        @test sc.profiled_units_by_name["g7"].name == "g7"

        pu2 = sc.profiled_units[2]
        @test pu2.name == "g8"
        @test pu2.bus.name == "b5"
        @test pu2.cost == [50.0 for t in 1:4]
        @test pu2.min_power == [0.0 for t in 1:4]
        @test pu2.max_power == [120.0 for t in 1:4]
        @test sc.profiled_units_by_name["g8"].name == "g8"
    end

    @testset "read_benchmark commitmemt-status" begin
        instance = UnitCommitment.read(fixture("case14-fixed-status.json.gz"))
        sc = instance.scenarios[1]

        @test sc.thermal_units[1].commitment_status == [nothing for t in 1:4]
        @test sc.thermal_units[2].commitment_status == [true for t in 1:4]
        @test sc.thermal_units[4].commitment_status == [false for t in 1:4]
        @test sc.thermal_units[6].commitment_status ==
              [false, nothing, true, nothing]
    end

    @testset "read_benchmark storage" begin
        instance = UnitCommitment.read(fixture("case14-storage.json.gz"))
        sc = instance.scenarios[1]
        @test length(sc.storage_units) == 4

        su1 = sc.storage_units[1]
        @test su1.name == "su1"
        @test su1.bus.name == "b2"
        @test su1.min_level == [0.0 for t in 1:4]
        @test su1.max_level == [100.0 for t in 1:4]
        @test su1.simultaneous_charge_and_discharge == [true for t in 1:4]
        @test su1.charge_cost == [2.0 for t in 1:4]
        @test su1.discharge_cost == [2.5 for t in 1:4]
        @test su1.charge_efficiency == [1.0 for t in 1:4]
        @test su1.discharge_efficiency == [1.0 for t in 1:4]
        @test su1.loss_factor == [0.0 for t in 1:4]
        @test su1.min_charge_rate == [0.0 for t in 1:4]
        @test su1.max_charge_rate == [10.0 for t in 1:4]
        @test su1.min_discharge_rate == [0.0 for t in 1:4]
        @test su1.max_discharge_rate == [8.0 for t in 1:4]
        @test su1.initial_level == 0.0
        @test su1.min_ending_level == 0.0
        @test su1.max_ending_level == 100.0
        @test sc.storage_units_by_name["su1"].name == "su1"

        su2 = sc.storage_units[2]
        @test su2.name == "su2"
        @test su2.bus.name == "b2"
        @test su2.min_level == [10.0 for t in 1:4]
        @test su2.simultaneous_charge_and_discharge == [false for t in 1:4]
        @test su2.charge_cost == [3.0 for t in 1:4]
        @test su2.discharge_cost == [3.5 for t in 1:4]
        @test su2.charge_efficiency == [0.8 for t in 1:4]
        @test su2.discharge_efficiency == [0.85 for t in 1:4]
        @test su2.loss_factor == [0.01 for t in 1:4]
        @test su2.min_charge_rate == [5.0 for t in 1:4]
        @test su2.min_discharge_rate == [2.0 for t in 1:4]
        @test su2.initial_level == 70.0
        @test su2.min_ending_level == 80.0
        @test su2.max_ending_level == 85.0
        @test sc.storage_units_by_name["su2"].name == "su2"

        su3 = sc.storage_units[3]
        @test su3.bus.name == "b9"
        @test su3.min_level == [10.0, 11.0, 12.0, 13.0]
        @test su3.max_level == [100.0, 110.0, 120.0, 130.0]
        @test su3.charge_cost == [2.0, 2.1, 2.2, 2.3]
        @test su3.discharge_cost == [1.0, 1.1, 1.2, 1.3]
        @test su3.charge_efficiency == [0.8, 0.81, 0.82, 0.82]
        @test su3.discharge_efficiency == [0.85, 0.86, 0.87, 0.88]
        @test su3.min_charge_rate == [5.0, 5.1, 5.2, 5.3]
        @test su3.max_charge_rate == [10.0, 10.1, 10.2, 10.3]
        @test su3.min_discharge_rate == [4.0, 4.1, 4.2, 4.3]
        @test su3.max_discharge_rate == [8.0, 8.1, 8.2, 8.3]

        su4 = sc.storage_units[4]
        @test su4.simultaneous_charge_and_discharge ==
              [false, false, true, true]
    end

    @testset "read_benchmark interface" begin
        instance = UnitCommitment.read(fixture("case14-interface.json.gz"))
        sc = instance.scenarios[1]
        @test length(sc.interfaces) == 1
        @test sc.interfaces_by_name["ifc1"].name == "ifc1"

        ifc = sc.interfaces[1]
        @test ifc.name == "ifc1"
        @test ifc.offset == 1
        @test length(ifc.outbound_lines) == 6
        @test length(ifc.inbound_lines) == 1
        @test ifc.net_flow_upper_limit == [2000 for t in 1:4]
        @test ifc.net_flow_lower_limit == [-1500 for t in 1:4]
        @test ifc.flow_limit_penalty == [9999.0 for t in 1:4]
    end
end
