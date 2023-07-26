# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using UnitCommitment, DataStructures, Cbc, HiGHS
import UnitCommitment: TimeDecomposition, ConventionalLMP

function solution_methods_TimeDecomposition_optimize_test()
    @testset "optimize_time_decomposition" begin
        # read one scenario
        instance = UnitCommitment.read(fixture("case14.json.gz"))
        solution = UnitCommitment.optimize!(
            instance,
            TimeDecomposition(time_window = 3, time_increment = 2),
            optimizer = optimizer_with_attributes(
                Cbc.Optimizer,
                "logLevel" => 0,
            ),
        )
        @test length(solution["Thermal production (MW)"]["g1"]) == 4
        @test length(solution["Is on"]["g2"]) == 4
        @test length(solution["Spinning reserve (MW)"]["r1"]["g2"]) == 4

        # read one scenario with after_build and after_optimize
        function after_build(model, instance)
            @constraint(
                model,
                model[:is_on]["g3", 1] + model[:is_on]["g4", 1] <= 1,
            )
        end

        lmps = []
        function after_optimize(solution, model, instance)
            lmp = UnitCommitment.compute_lmp(
                model,
                ConventionalLMP(),
                optimizer = optimizer_with_attributes(
                    HiGHS.Optimizer,
                    "log_to_console" => false,
                ),
            )
            return push!(lmps, lmp)
        end

        instance = UnitCommitment.read(fixture("case14-profiled.json.gz"))
        solution = UnitCommitment.optimize!(
            instance,
            TimeDecomposition(time_window = 3, time_increment = 2),
            optimizer = optimizer_with_attributes(
                Cbc.Optimizer,
                "logLevel" => 0,
            ),
            after_build = after_build,
            after_optimize = after_optimize,
        )
        @test length(lmps) == 2
        @test lmps[1]["s1", "b1", 1] == 50.0
        @test lmps[2]["s1", "b10", 2] ≈ 38.04 atol = 0.1
        @test solution["Is on"]["g3"][1] == 1.0
        @test solution["Is on"]["g4"][1] == 0.0

        # read multiple scenarios
        instance = UnitCommitment.read([
            fixture("case14.json.gz"),
            fixture("case14-profiled.json.gz"),
        ])
        solution = UnitCommitment.optimize!(
            instance,
            TimeDecomposition(time_window = 3, time_increment = 2),
            optimizer = optimizer_with_attributes(
                Cbc.Optimizer,
                "logLevel" => 0,
            ),
        )
        @test length(solution["case14"]["Thermal production (MW)"]["g3"]) == 4
        @test length(solution["case14"]["Is on"]["g4"]) == 4
        @test length(
            solution["case14-profiled"]["Thermal production (MW)"]["g5"],
        ) == 4
        @test length(solution["case14-profiled"]["Is on"]["g6"]) == 4
        @test length(
            solution["case14-profiled"]["Profiled production (MW)"]["g7"],
        ) == 4
        @test length(
            solution["case14-profiled"]["Spinning reserve (MW)"]["r1"]["g3"],
        ) == 4
    end
end
