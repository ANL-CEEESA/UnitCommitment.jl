# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using UnitCommitment, DataStructures

@testset "determine_initial_status" begin
    t_increment = 24
    t_model = 36
    hot_start = 100
    cold_start = -100

    # all on throughout
    stat_seq = ones(t_model)
    # hot start
    new_stat = UnitCommitment._determine_initial_status(
        hot_start,
        stat_seq,
        t_increment,
    )
    @test new_stat == 124
    # cold start
    new_stat = UnitCommitment._determine_initial_status(
        cold_start,
        stat_seq,
        t_increment,
    )
    @test new_stat == 24

    # off in the last 12 periods
    stat_seq = ones(t_model)
    stat_seq[25:end] .= 0
    # hot start
    new_stat = UnitCommitment._determine_initial_status(
        hot_start,
        stat_seq,
        t_increment,
    )
    @test new_stat == 124
    # cold start
    new_stat = UnitCommitment._determine_initial_status(
        cold_start,
        stat_seq,
        t_increment,
    )
    @test new_stat == 24

    # off in one of the first 24 periods
    stat_seq = ones(t_model)
    stat_seq[10] = 0
    # hot start
    new_stat = UnitCommitment._determine_initial_status(
        hot_start,
        stat_seq,
        t_increment,
    )
    @test new_stat == 14
    # cold start
    new_stat = UnitCommitment._determine_initial_status(
        cold_start,
        stat_seq,
        t_increment,
    )
    @test new_stat == 14

    # off in several of the first 24 periods
    stat_seq = ones(t_model)
    stat_seq[[10, 11, 20]] .= 0
    # hot start
    new_stat = UnitCommitment._determine_initial_status(
        hot_start,
        stat_seq,
        t_increment,
    )
    @test new_stat == 4
    # cold start
    new_stat = UnitCommitment._determine_initial_status(
        cold_start,
        stat_seq,
        t_increment,
    )
    @test new_stat == 4

    # off in several of the first 24 periods
    stat_seq = ones(t_model)
    stat_seq[20:24] .= 0
    # hot start
    new_stat = UnitCommitment._determine_initial_status(
        hot_start,
        stat_seq,
        t_increment,
    )
    @test new_stat == -5
    # cold start
    new_stat = UnitCommitment._determine_initial_status(
        cold_start,
        stat_seq,
        t_increment,
    )
    @test new_stat == -5

    # all off throughout
    stat_seq = zeros(t_model)
    # hot start
    new_stat = UnitCommitment._determine_initial_status(
        hot_start,
        stat_seq,
        t_increment,
    )
    @test new_stat == -24
    # cold start
    new_stat = UnitCommitment._determine_initial_status(
        cold_start,
        stat_seq,
        t_increment,
    )
    @test new_stat == -124

    # on in the last 12 periods
    stat_seq = zeros(t_model)
    stat_seq[25:end] .= 1
    # hot start
    new_stat = UnitCommitment._determine_initial_status(
        hot_start,
        stat_seq,
        t_increment,
    )
    @test new_stat == -24
    # cold start
    new_stat = UnitCommitment._determine_initial_status(
        cold_start,
        stat_seq,
        t_increment,
    )
    @test new_stat == -124
end

@testset "set_initial_status" begin
    # read one scenario
    instance = UnitCommitment.read("$FIXTURES/case14.json.gz")
    psuedo_solution = OrderedDict(
        "Thermal production (MW)" => OrderedDict(
            "g1" => [110.0, 112.0, 114.0, 116.0],
            "g2" => [100.0, 102.0, 0.0, 0.0],
            "g3" => [0.0, 0.0, 0.0, 0.0],
            "g4" => [33.0, 34.0, 66.0, 99.0],
            "g5" => [33.0, 34.0, 66.0, 99.0],
            "g6" => [100.0, 100.0, 100.0, 100.0],
        ),
        "Is on" => OrderedDict(
            "g1" => [1.0, 1.0, 1.0, 1.0],
            "g2" => [1.0, 1.0, 0.0, 0.0],
            "g3" => [0.0, 0.0, 0.0, 0.0],
            "g4" => [1.0, 1.0, 1.0, 1.0],
            "g5" => [1.0, 1.0, 1.0, 1.0],
            "g6" => [1.0, 1.0, 1.0, 1.0],
        ),
    )
    UnitCommitment._set_initial_status!(instance, psuedo_solution, 3)
    thermal_units = instance.scenarios[1].thermal_units
    @test thermal_units[1].initial_power == 114.0
    @test thermal_units[1].initial_status == 3.0
    @test thermal_units[2].initial_power == 0.0
    @test thermal_units[2].initial_status == -1.0
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
                "g1" => [110.0, 112.0, 114.0, 116.0],
                "g2" => [100.0, 102.0, 0.0, 0.0],
                "g3" => [0.0, 0.0, 0.0, 0.0],
                "g4" => [33.0, 34.0, 66.0, 99.0],
                "g5" => [33.0, 34.0, 66.0, 99.0],
                "g6" => [100.0, 100.0, 100.0, 100.0],
            ),
            "Is on" => OrderedDict(
                "g1" => [1.0, 1.0, 1.0, 1.0],
                "g2" => [1.0, 1.0, 0.0, 0.0],
                "g3" => [0.0, 0.0, 0.0, 0.0],
                "g4" => [1.0, 1.0, 1.0, 1.0],
                "g5" => [1.0, 1.0, 1.0, 1.0],
                "g6" => [1.0, 1.0, 1.0, 1.0],
            ),
        ),
        "case14-profiled" => OrderedDict(
            "Thermal production (MW)" => OrderedDict(
                "g1" => [112.0, 113.0, 116.0, 115.0],
                "g2" => [0.0, 0.0, 0.0, 0.0],
                "g3" => [0.0, 0.0, 0.0, 20.0],
                "g4" => [33.0, 34.0, 66.0, 99.0],
                "g5" => [33.0, 34.0, 66.0, 99.0],
                "g6" => [100.0, 100.0, 100.0, 100.0],
            ),
            "Is on" => OrderedDict(
                "g1" => [1.0, 1.0, 1.0, 1.0],
                "g2" => [0.0, 0.0, 0.0, 0.0],
                "g3" => [0.0, 0.0, 0.0, 0.0],
                "g4" => [1.0, 1.0, 1.0, 1.0],
                "g5" => [1.0, 1.0, 1.0, 1.0],
                "g6" => [1.0, 1.0, 1.0, 1.0],
            ),
        ),
    )
    UnitCommitment._set_initial_status!(instance, psuedo_solution, 3)
    thermal_units_sc2 = instance.scenarios[2].thermal_units
    @test thermal_units_sc2[1].initial_power == 116.0
    @test thermal_units_sc2[1].initial_status == 3.0
    @test thermal_units_sc2[2].initial_power == 0.0
    @test thermal_units_sc2[2].initial_status == -11.0
    @test thermal_units_sc2[3].initial_power == 0.0
    @test thermal_units_sc2[3].initial_status == -9.0
end
