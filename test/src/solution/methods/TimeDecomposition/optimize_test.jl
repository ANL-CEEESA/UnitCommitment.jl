# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using UnitCommitment, DataStructures, HiGHS
import UnitCommitment: TimeDecomposition

function solution_methods_TimeDecomposition_optimize_test()
    @testset "optimize_time_decomposition" begin
        # read one scenario
        instance = UnitCommitment.read(fixture("case14.json.gz"))
        solution = UnitCommitment.optimize!(
            instance,
            TimeDecomposition(time_window = 3, time_increment = 2),
            optimizer = optimizer_with_attributes(
                HiGHS.Optimizer,
                "log_to_console" => false,
            ),
        )
        @test length(solution["Thermal: Production (MW)"]["g1"]) == 4
        @test length(solution["Thermal: Is on"]["g2"]) == 4
        @test length(solution["Reserve: Spinning (MW)"]["r1"]["g2"]) == 4

        # read multiple scenarios
        instance = UnitCommitment.read([
            fixture("case14.json.gz"),
            fixture("case14-profiled.json.gz"),
        ])
        solution = UnitCommitment.optimize!(
            instance,
            TimeDecomposition(time_window = 3, time_increment = 2),
            optimizer = optimizer_with_attributes(
                HiGHS.Optimizer,
                "log_to_console" => false,
            ),
        )
        @test length(solution["case14"]["Thermal: Production (MW)"]["g3"]) == 4
        @test length(solution["case14"]["Thermal: Is on"]["g4"]) == 4
        @test length(
            solution["case14-profiled"]["Thermal: Production (MW)"]["g5"],
        ) == 4
        @test length(solution["case14-profiled"]["Thermal: Is on"]["g6"]) == 4
        @test length(
            solution["case14-profiled"]["Profiled: Production (MW)"]["g7"],
        ) == 4
        @test length(
            solution["case14-profiled"]["Reserve: Spinning (MW)"]["r1"]["g3"],
        ) == 4
    end
end
