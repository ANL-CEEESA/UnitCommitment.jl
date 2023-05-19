# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using UnitCommitment, DataStructures, Cbc
import UnitCommitment: TimeDecomposition, XavQiuWanThi2019, Formulation

@testset "optimize_time_decomposition" begin
    # read one scenario
    instance = UnitCommitment.read("$FIXTURES/case14.json.gz")
    solution = UnitCommitment.optimize!(
        instance,
        TimeDecomposition(
            time_window = 3,
            time_increment = 2,
            inner_method = XavQiuWanThi2019.Method(),
            formulation = Formulation(),
        ),
        optimizer = optimizer_with_attributes(Cbc.Optimizer, "logLevel" => 0),
    )
    @test length(solution["Thermal production (MW)"]["g1"]) == 4
    @test length(solution["Is on"]["g2"]) == 4
    @test length(solution["Spinning reserve (MW)"]["r1"]["g2"]) == 4

    # read multiple scenarios
    instance = UnitCommitment.read([
        "$FIXTURES/case14.json.gz",
        "$FIXTURES/case14-profiled.json.gz",
    ])
    solution = UnitCommitment.optimize!(
        instance,
        TimeDecomposition(
            time_window = 3,
            time_increment = 2,
            inner_method = XavQiuWanThi2019.Method(),
            formulation = Formulation(),
        ),
        optimizer = optimizer_with_attributes(Cbc.Optimizer, "logLevel" => 0),
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
