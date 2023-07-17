# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

import Random
import UnitCommitment: XavQiuAhm2021

using Distributions
using Random
using UnitCommitment, Cbc, JuMP

function get_scenario()
    return UnitCommitment.read_benchmark(
        "matpower/case118/2017-02-01",
    ).scenarios[1]
end
system_load(sc) = sum(b.load for b in sc.buses)
test_approx(x, y) = @test isapprox(x, y, atol = 1e-3)

function transform_randomize_XavQiuAhm2021_test()
    @testset "XavQiuAhm2021" begin
        @testset "cost and load share" begin
            sc = get_scenario()
            # Check original costs
            unit = sc.thermal_units[10]
            test_approx(unit.min_power_cost[1], 825.023)
            test_approx(unit.cost_segments[1].cost[1], 36.659)
            test_approx(unit.startup_categories[1].cost[1], 7570.42)

            # Check original load share
            bus = sc.buses[1]
            prev_system_load = system_load(sc)
            test_approx(bus.load[1] / prev_system_load[1], 0.012)

            randomize!(
                sc,
                XavQiuAhm2021.Randomization(randomize_load_profile = false),
                rng = MersenneTwister(42),
            )

            # Check randomized costs
            test_approx(unit.min_power_cost[1], 831.977)
            test_approx(unit.cost_segments[1].cost[1], 36.968)
            test_approx(unit.startup_categories[1].cost[1], 7634.226)

            # Check randomized load share
            curr_system_load = system_load(sc)
            test_approx(bus.load[1] / curr_system_load[1], 0.013)

            # System load should not change
            @test prev_system_load ≈ curr_system_load
        end

        @testset "load profile" begin
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
                4854.7,
                4849.2,
                4732.7,
                4848.2,
                4948.4,
                5231.1,
                5874.8,
                5934.8,
            ]
        end

        @testset "profiled unit cost" begin
            sc = UnitCommitment.read(
                fixture("case14-profiled.json.gz"),
            ).scenarios[1]
            # Check original costs
            pu1 = sc.profiled_units[1]
            pu2 = sc.profiled_units[2]
            test_approx(pu1.cost[1], 100.0)
            test_approx(pu2.cost[1], 50.0)
            randomize!(
                sc,
                XavQiuAhm2021.Randomization(randomize_load_profile = false),
                rng = MersenneTwister(42),
            )
            # Check randomized costs
            test_approx(pu1.cost[1], 98.039)
            test_approx(pu2.cost[1], 48.385)
        end

        @testset "storage unit cost" begin
            sc = UnitCommitment.read(
                fixture("case14-storage.json.gz"),
            ).scenarios[1]
            # Check original costs
            su1 = sc.storage_units[1]
            su3 = sc.storage_units[3]
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
            test_approx(su1.charge_cost[4], 1.961)
            test_approx(su1.discharge_cost[1], 2.451)
            test_approx(su3.charge_cost[2], 2.196)
            test_approx(su3.discharge_cost[3], 1.255)
        end
    end
end
