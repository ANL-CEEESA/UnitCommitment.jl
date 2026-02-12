# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

import Random
import UnitCommitment: XavQiuAhm2021

using Distributions
using Random
using UnitCommitment, JuMP

function get_scenario()
    return UnitCommitment.read_benchmark(
        "matpower/case118/2017-02-01",
    ).scenarios[1]
end
system_load(sc) = sum(b.load for b in sc[:bus])
test_approx(x, y) = @test isapprox(x, y, atol = 1e-3)

@testfunction transform_randomize_XavQiuAhm2021_rng_smoke_test begin
    # Verify MersenneTwister(42) produces expected sequence
    # This helps detect if Julia version changes RNG behavior
    rng = MersenneTwister(42)
    @test rand(rng) ≈ 0.7108238673434464
    @test rand(rng) ≈ 0.0644852510983267
    @test rand(rng) ≈ 0.477842641066915
    @test rand(rng, Uniform(0.95, 1.05)) ≈ 0.9677709305579533
end

@testfunction transform_randomize_XavQiuAhm2021_cost_and_load_share_test begin
    sc = get_scenario()
    # Check original costs
    unit = sc[:thermal][10]
    test_approx(unit.min_power_cost[1], 825.023)
    test_approx(unit.cost_segments[1].cost[1], 36.659)
    test_approx(unit.startup_categories[1].cost[1], 7570.42)

    # Check original load share
    bus = sc[:bus][1]
    prev_system_load = system_load(sc)
    test_approx(bus.load[1] / prev_system_load[1], 0.012)

    randomize!(
        sc,
        XavQiuAhm2021.Randomization(randomize_load_profile = false),
        rng = MersenneTwister(42),
    )

    # Check randomized costs
    test_approx(unit.min_power_cost[1], 821.941)
    test_approx(unit.cost_segments[1].cost[1], 36.522)
    test_approx(unit.startup_categories[1].cost[1], 7542.135)

    # Check randomized load share
    curr_system_load = system_load(sc)
    test_approx(bus.load[1] / curr_system_load[1], 0.013)

    # System load should not change
    @test prev_system_load ≈ curr_system_load
end

@testfunction transform_randomize_XavQiuAhm2021_load_profile_test begin
    sc = get_scenario()
    # Check original load profile
    @test round.(system_load(sc), digits = 1)[1:8] ≈ [
        3059.5,
        2983.2,
        2937.5,
        2953.9,
        3073.1,
        3356.4,
        4068.5,
        4018.8,
    ]

    randomize!(
        sc,
        XavQiuAhm2021.Randomization();
        rng = MersenneTwister(42),
    )

    # Check randomized load profile
    @test round.(system_load(sc), digits = 1)[1:8] ≈ [
        4089.7,
        3996.3,
        3847.2,
        3876.7,
        3887.5,
        4127.3,
        4923.5,
        5087.3,
    ]
end

@testfunction transform_randomize_XavQiuAhm2021_profiled_unit_cost_test begin
    sc = UnitCommitment.read(
        fixture("case14-profiled.json.gz"),
    ).scenarios[1]
    # Check original costs
    pu1 = sc[:profiled][1]
    pu2 = sc[:profiled][2]
    test_approx(pu1.cost[1], 100.0)
    test_approx(pu2.cost[1], 50.0)
    randomize!(
        sc,
        XavQiuAhm2021.Randomization(randomize_load_profile = false),
        rng = MersenneTwister(42),
    )
    # Check randomized costs
    test_approx(pu1.cost[1], 99.476)
    test_approx(pu2.cost[1], 48.218)
end

@testfunction transform_randomize_XavQiuAhm2021_storage_unit_cost_test begin
    sc = UnitCommitment.read(
        fixture("case14-storage.json.gz"),
    ).scenarios[1]
    # Check original costs
    su1 = sc[:storage][1]
    su3 = sc[:storage][3]
    test_approx(su1.charge_cost[4], 2.0)
    test_approx(su1.discharge_cost[1], 2.5)
    test_approx(su3.charge_cost[2], 2.1)
    test_approx(su3.discharge_cost[3], 1.2)
    randomize!(
        sc,
        XavQiuAhm2021.Randomization(randomize_load_profile = false),
        rng = MersenneTwister(42),
    )
    # Check randomized costs
    test_approx(su1.charge_cost[4], 1.990)
    test_approx(su1.discharge_cost[1], 2.487)
    test_approx(su3.charge_cost[2], 2.039)
    test_approx(su3.discharge_cost[3], 1.165)
end
