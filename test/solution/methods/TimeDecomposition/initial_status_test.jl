# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using UnitCommitment, DataStructures

@testset "determine_initial_status" begin
    hot_start = 100
    cold_start = -100

    # all on throughout
    stat_seq = ones(36)
    # hot start
    new_stat = UnitCommitment._determine_initial_status(hot_start, stat_seq)
    @test new_stat == 136
    # cold start
    new_stat = UnitCommitment._determine_initial_status(cold_start, stat_seq)
    @test new_stat == 36

    # off in the last 12 periods
    stat_seq = ones(36)
    stat_seq[25:end] .= 0
    # hot start
    new_stat = UnitCommitment._determine_initial_status(hot_start, stat_seq)
    @test new_stat == -12
    # cold start
    new_stat = UnitCommitment._determine_initial_status(cold_start, stat_seq)
    @test new_stat == -12

    # off in one period
    stat_seq = ones(36)
    stat_seq[10] = 0
    # hot start
    new_stat = UnitCommitment._determine_initial_status(hot_start, stat_seq)
    @test new_stat == 26
    # cold start
    new_stat = UnitCommitment._determine_initial_status(cold_start, stat_seq)
    @test new_stat == 26

    # off in several of the first 24 periods
    stat_seq = ones(36)
    stat_seq[[10, 11, 20]] .= 0
    # hot start
    new_stat = UnitCommitment._determine_initial_status(hot_start, stat_seq)
    @test new_stat == 16
    # cold start
    new_stat = UnitCommitment._determine_initial_status(cold_start, stat_seq)
    @test new_stat == 16

    # all off throughout
    stat_seq = zeros(36)
    # hot start
    new_stat = UnitCommitment._determine_initial_status(hot_start, stat_seq)
    @test new_stat == -36
    # cold start
    new_stat = UnitCommitment._determine_initial_status(cold_start, stat_seq)
    @test new_stat == -136

    # on in the last 12 periods
    stat_seq = zeros(36)
    stat_seq[25:end] .= 1
    # hot start
    new_stat = UnitCommitment._determine_initial_status(hot_start, stat_seq)
    @test new_stat == 12
    # cold start
    new_stat = UnitCommitment._determine_initial_status(cold_start, stat_seq)
    @test new_stat == 12
end

@testset "set_initial_status" begin
    # read one scenario
    instance = UnitCommitment.read("$FIXTURES/case14.json.gz")
    psuedo_solution = OrderedDict(
        "Thermal production (MW)" => OrderedDict(
            "g1" => [0.0, 112.0, 114.0, 116.0],
            "g2" => [0.0, 102.0, 0.0, 0.0],
            "g3" => [0.0, 0.0, 0.0, 0.0],
            "g4" => [0.0, 34.0, 66.0, 99.0],
            "g5" => [0.0, 34.0, 66.0, 99.0],
            "g6" => [0.0, 100.0, 100.0, 100.0],
        ),
        "Is on" => OrderedDict(
            "g1" => [0.0, 1.0, 1.0, 1.0],
            "g2" => [0.0, 1.0, 0.0, 0.0],
            "g3" => [0.0, 0.0, 0.0, 0.0],
            "g4" => [0.0, 1.0, 1.0, 1.0],
            "g5" => [0.0, 1.0, 1.0, 1.0],
            "g6" => [0.0, 1.0, 1.0, 1.0],
        ),
    )
    UnitCommitment._set_initial_status!(instance, psuedo_solution, 3)
    thermal_units = instance.scenarios[1].thermal_units
    @test thermal_units[1].initial_power == 116.0
    @test thermal_units[1].initial_status == 3.0
    @test thermal_units[2].initial_power == 0.0
    @test thermal_units[2].initial_status == -2.0
    @test thermal_units[3].initial_power == 0.0
    @test thermal_units[3].initial_status == -9.0

    # read multiple scenarios
    instance = UnitCommitment.read([
        "$FIXTURES/case14.json.gz",
        "$FIXTURES/case14-profiled.json.gz",
    ])
    psuedo_solution = OrderedDict(
        "case14" => OrderedDict(
            "Thermal production (MW)" => OrderedDict(
                "g1" => [0.0, 112.0, 114.0, 116.0],
                "g2" => [0.0, 102.0, 0.0, 0.0],
                "g3" => [0.0, 0.0, 0.0, 0.0],
                "g4" => [0.0, 34.0, 66.0, 99.0],
                "g5" => [0.0, 34.0, 66.0, 99.0],
                "g6" => [0.0, 100.0, 100.0, 100.0],
            ),
            "Is on" => OrderedDict(
                "g1" => [0.0, 1.0, 1.0, 1.0],
                "g2" => [0.0, 1.0, 0.0, 0.0],
                "g3" => [0.0, 0.0, 0.0, 0.0],
                "g4" => [0.0, 1.0, 1.0, 1.0],
                "g5" => [0.0, 1.0, 1.0, 1.0],
                "g6" => [0.0, 1.0, 1.0, 1.0],
            ),
        ),
        "case14-profiled" => OrderedDict(
            "Thermal production (MW)" => OrderedDict(
                "g1" => [0.0, 113.0, 116.0, 115.0],
                "g2" => [0.0, 0.0, 0.0, 0.0],
                "g3" => [0.0, 0.0, 0.0, 20.0],
                "g4" => [0.0, 34.0, 66.0, 98.0],
                "g5" => [0.0, 34.0, 66.0, 97.0],
                "g6" => [0.0, 100.0, 100.0, 100.0],
            ),
            "Is on" => OrderedDict(
                "g1" => [0.0, 1.0, 1.0, 1.0],
                "g2" => [0.0, 0.0, 0.0, 0.0],
                "g3" => [0.0, 0.0, 0.0, 1.0],
                "g4" => [0.0, 1.0, 1.0, 1.0],
                "g5" => [0.0, 1.0, 1.0, 1.0],
                "g6" => [0.0, 1.0, 1.0, 1.0],
            ),
        ),
    )
    UnitCommitment._set_initial_status!(instance, psuedo_solution, 3)
    thermal_units_sc2 = instance.scenarios[2].thermal_units
    @test thermal_units_sc2[1].initial_power == 115.0
    @test thermal_units_sc2[1].initial_status == 3.0
    @test thermal_units_sc2[2].initial_power == 0.0
    @test thermal_units_sc2[2].initial_status == -11.0
    @test thermal_units_sc2[3].initial_power == 20.0
    @test thermal_units_sc2[3].initial_status == 1.0
end
