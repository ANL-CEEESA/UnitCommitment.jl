# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

import Random
import UnitCommitment: XavQiuAhm2021

using Distributions
using Random
using UnitCommitment, Cbc, JuMP

get_instance() = UnitCommitment.read_benchmark("matpower/case118/2017-02-01")
system_load(sc) = sum(b.load for b in sc.buses)
test_approx(x, y) = @test isapprox(x, y, atol = 1e-3)

@testset "XavQiuAhm2021" begin
    @testset "cost and load share" begin
        instance = get_instance()
        for sc in instance.scenarios
            # Check original costs
            unit = sc.units[10]
            test_approx(unit.min_power_cost[1], 825.023)
            test_approx(unit.cost_segments[1].cost[1], 36.659)
            test_approx(unit.startup_categories[1].cost[1], 7570.42)

            # Check original load share
            bus = sc.buses[1]
            prev_system_load = system_load(sc)
            test_approx(bus.load[1] / prev_system_load[1], 0.012)

            randomize!(
                sc,
                method = XavQiuAhm2021.Randomization(
                    randomize_load_profile = false,
                ),
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
    end

    @testset "load profile" begin
        instance = get_instance()
        for sc in instance.scenarios
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
                sc;
                method = XavQiuAhm2021.Randomization(),
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
    end
end
