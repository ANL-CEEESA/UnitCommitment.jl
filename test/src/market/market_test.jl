# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

@testfunction market_simple_test begin
    da_path = fixture("market_da_simple.json.gz")
    rt_paths = [
        fixture("market_rt1_simple.json.gz"),
        fixture("market_rt2_simple.json.gz"),
        fixture("market_rt3_simple.json.gz"),
        fixture("market_rt4_simple.json.gz"),
    ]
    # solve market with default setting
    solution = UnitCommitment.solve_market(
        da_path,
        rt_paths,
        settings = UnitCommitment.MarketSettings(),
        optimizer = test_optimizer(),
    )

    # the commitment status must agree with DA market
    da_solution = solution["DA"]
    @test da_solution["Thermal: Is on"]["GenY"] == [0.0, 1.0]

    rt_solution = solution["RT"]
    @test length(rt_solution) == 4
    @test rt_solution[1]["Thermal: Is on"]["GenY"] == [0.0, 0.0]
    @test rt_solution[2]["Thermal: Is on"]["GenY"] == [0.0, 1.0]
    @test rt_solution[3]["Thermal: Is on"]["GenY"] == [1.0, 1.0]
    @test rt_solution[4]["Thermal: Is on"]["GenY"] == [1.0]
end

@testfunction market_stochastic_test begin
    da_path = [
        fixture("market_da_simple.json.gz"),
        fixture("market_da_scenario.json.gz"),
    ]
    rt_paths = [
        fixture("market_rt1_simple.json.gz"),
        fixture("market_rt2_simple.json.gz"),
        fixture("market_rt3_simple.json.gz"),
        fixture("market_rt4_simple.json.gz"),
    ]

    # solve the stochastic market
    solution = UnitCommitment.solve_market(
        da_path,
        rt_paths,
        settings = UnitCommitment.MarketSettings(),
        optimizer = test_optimizer(),
    )
    # the commitment status must agree with DA market
    da_solution_sp = solution["DA"]["market_da_simple"]
    da_solution_sc = solution["DA"]["market_da_scenario"]
    @test da_solution_sp["Thermal: Is on"]["GenY"] == [0.0, 1.0]
    @test da_solution_sc["Thermal: Is on"]["GenY"] == [0.0, 1.0]

    rt_solution = solution["RT"]
    @test rt_solution[1]["Thermal: Is on"]["GenY"] == [0.0, 0.0]
    @test rt_solution[2]["Thermal: Is on"]["GenY"] == [0.0, 1.0]
    @test rt_solution[3]["Thermal: Is on"]["GenY"] == [1.0, 1.0]
    @test rt_solution[4]["Thermal: Is on"]["GenY"] == [1.0]
end
