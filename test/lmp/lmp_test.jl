# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using UnitCommitment, Cbc, Clp, JuMP

function solve_lmp_testcase(path::String)
    instance = UnitCommitment.read(path)
    model = UnitCommitment.build_model(
        instance = instance,
        optimizer = Cbc.Optimizer,
        variable_names = true,
    )
    # set silent, solve the UC
    JuMP.set_silent(model)
    UnitCommitment.optimize!(model)
    # get the lmp
    lmp = UnitCommitment.get_lmp(
        model,
        optimizer=Clp.Optimizer,
        verbose=false
    )
    return lmp
end

@testset "lmp" begin
    # instance 1
    path = "$FIXTURES/lmp_simple_test_1.json.gz"
    lmp = solve_lmp_testcase(path)
    @test lmp["A", 1] == 50.0
    @test lmp["B", 1] == 50.0

    # instance 2
    path = "$FIXTURES/lmp_simple_test_2.json.gz"
    lmp = solve_lmp_testcase(path)
    @test lmp["A", 1] == 50.0
    @test lmp["B", 1] == 60.0

    # instance 3
    path = "$FIXTURES/lmp_simple_test_3.json.gz"
    lmp = solve_lmp_testcase(path)
    @test lmp["A", 1] == 50.0
    @test lmp["B", 1] == 70.0
    @test lmp["C", 1] == 100.0

    # instance 4
    path = "$FIXTURES/lmp_simple_test_4.json.gz"
    lmp = solve_lmp_testcase(path)
    @test lmp["A", 1] == 50.0
    @test lmp["B", 1] == 70.0
    @test lmp["C", 1] == 90.0
end