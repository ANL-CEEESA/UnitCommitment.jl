# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using UnitCommitment, HiGHS, JuMP

function solve_conventional_testcase(path::String)
    instance = UnitCommitment.read(path)
    model = UnitCommitment.build_model(
        instance = instance,
        optimizer = optimizer_with_attributes(
            HiGHS.Optimizer,
            "log_to_console" => false,
        ),
        variable_names = true,
    )
    JuMP.set_silent(model)
    UnitCommitment.optimize!(model)
    lmp = UnitCommitment.compute_lmp(
        model,
        ConventionalLMP(),
        optimizer = optimizer_with_attributes(
            HiGHS.Optimizer,
            "log_to_console" => false,
        ),
    )
    return lmp
end

function lmp_conventional_test()
    @testset "conventional" begin
        # instance 1
        path = fixture("lmp_simple_test_1.json.gz")
        lmp = solve_conventional_testcase(path)
        @test lmp["s1", "A", 1] == 50.0
        @test lmp["s1", "B", 1] == 50.0

        # instance 2
        path = fixture("lmp_simple_test_2.json.gz")
        lmp = solve_conventional_testcase(path)
        @test lmp["s1", "A", 1] == 50.0
        @test lmp["s1", "B", 1] == 60.0

        # instance 3
        path = fixture("lmp_simple_test_3.json.gz")
        lmp = solve_conventional_testcase(path)
        @test lmp["s1", "A", 1] == 50.0
        @test lmp["s1", "B", 1] == 70.0
        @test lmp["s1", "C", 1] == 100.0

        # instance 4
        path = fixture("lmp_simple_test_4.json.gz")
        lmp = solve_conventional_testcase(path)
        @test lmp["s1", "A", 1] == 50.0
        @test lmp["s1", "B", 1] == 70.0
        @test lmp["s1", "C", 1] == 90.0
    end
end
