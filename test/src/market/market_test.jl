# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using UnitCommitment, HiGHS, JuMP
import UnitCommitment: MarketSettings

function simple_market_test()
    @testset "da-to-rt simple market" begin
        da_path = fixture("market_da_simple.json")
        rt_paths = [
            fixture("market_rt1_simple.json"),
            fixture("market_rt2_simple.json"),
            fixture("market_rt3_simple.json"),
            fixture("market_rt4_simple.json"),
        ]
        # solve market with default setting
        solution = UnitCommitment.solve_market(
            da_path,
            rt_paths,
            settings = MarketSettings(),
            optimizer = optimizer_with_attributes(
                HiGHS.Optimizer,
                "log_to_console" => false,
            ),
        )

        # the commitment status must agree with DA market
        da_solution = solution["DA"]
        @test da_solution["Is on"]["GenY"] == [0.0, 1.0]

        rt_solution = solution["RT"]
        @test length(rt_solution) == 4
        @test rt_solution[1]["Is on"]["GenY"] == [0.0, 0.0]
        @test rt_solution[2]["Is on"]["GenY"] == [0.0, 1.0]
        @test rt_solution[3]["Is on"]["GenY"] == [1.0, 1.0]
        @test rt_solution[4]["Is on"]["GenY"] == [1.0]
    end
end

function stochastic_market_test()
    @testset "da-to-rt stochastic market" begin
        da_path = [
            fixture("market_da_simple.json"),
            fixture("market_da_scenario.json"),
        ]
        rt_paths = [
            fixture("market_rt1_simple.json"),
            fixture("market_rt2_simple.json"),
            fixture("market_rt3_simple.json"),
            fixture("market_rt4_simple.json"),
        ]

        # solve the stochastic market
        solution = UnitCommitment.solve_market(
            da_path,
            rt_paths,
            settings = MarketSettings(),
            optimizer = optimizer_with_attributes(
                HiGHS.Optimizer,
                "log_to_console" => false,
            ),
        )
        # the commitment status must agree with DA market
        da_solution_sp = solution["DA"]["market_da_simple"]
        da_solution_sc = solution["DA"]["market_da_scenario"]
        @test da_solution_sp["Is on"]["GenY"] == [0.0, 1.0]
        @test da_solution_sc["Is on"]["GenY"] == [0.0, 1.0]

        rt_solution = solution["RT"]
        @test rt_solution[1]["Is on"]["GenY"] == [0.0, 0.0]
        @test rt_solution[2]["Is on"]["GenY"] == [0.0, 1.0]
        @test rt_solution[3]["Is on"]["GenY"] == [1.0, 1.0]
        @test rt_solution[4]["Is on"]["GenY"] == [1.0]
    end
end
