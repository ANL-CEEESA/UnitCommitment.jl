# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using UnitCommitment, HiGHS, JuMP

function solve_aelmp_testcase(
    path::String,
    allow_offline_participation::Bool,
    consider_startup_costs::Bool,
)
    instance = UnitCommitment.read(
        path,
        extensions = [
            UnitCommitment.AELMP(
                allow_offline_participation,
                consider_startup_costs,
                optimizer_with_attributes(
                    HiGHS.Optimizer,
                    "log_to_console" => false,
                ),
            ),
        ],
    )
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
    solution = UnitCommitment.solution(model)
    return solution["Locational marginal price (\$/MWh)"]
end

function lmp_aelmp_test()
    @testset "aelmp" begin
        path = fixture("aelmp_simple.json.gz")

        # policy 1: allow offlines; consider startups
        aelmp_1 = solve_aelmp_testcase(path, true, true)
        @test aelmp_1["B1", 1] ≈ 231.7 atol = 0.1

        # policy 2: do not allow offlines; but consider startups
        aelmp_2 = solve_aelmp_testcase(path, false, true)
        @test aelmp_2["B1", 1] ≈ 274.3 atol = 0.1
    end
end
