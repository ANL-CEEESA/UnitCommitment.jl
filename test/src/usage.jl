# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using UnitCommitment, LinearAlgebra, HiGHS, JuMP, JSON

function _set_flow_limits!(instance)
    for sc in instance.scenarios
        sc.power_balance_penalty = [100_000 for _ in 1:instance.time]
        for line in sc.lines, t in 1:4
            line.normal_flow_limit[t] = 10.0
        end
    end
end

function usage_test()
    @testset "usage" begin
        @testset "deterministic" begin
            instance = UnitCommitment.read(fixture("case14.json.gz"))
            _set_flow_limits!(instance)
            optimizer = optimizer_with_attributes(
                HiGHS.Optimizer,
                "log_to_console" => false,
            )
            model = UnitCommitment.build_model(
                instance = instance,
                optimizer = optimizer,
                variable_names = true,
            )
            @test name(model[:is_on]["g1", 1]) == "is_on[g1,1]"

            # Optimize and retrieve solution
            UnitCommitment.optimize!(model)
            solution = UnitCommitment.solution(model)

            # Write solution to a file
            filename = tempname()
            UnitCommitment.write(filename, solution)
            loaded = JSON.parsefile(filename)
            @test length(loaded["Is on"]) == 6

            # Verify solution
            @test UnitCommitment.validate(instance, solution)

            # Reoptimize with fixed solution
            UnitCommitment.fix!(model, solution)
            UnitCommitment.optimize!(model)
            @test UnitCommitment.validate(instance, solution)
        end

        @testset "stochastic" begin
            instance = UnitCommitment.read([
                fixture("case14.json.gz"),
                fixture("case14.json.gz"),
            ])
            _set_flow_limits!(instance)
            @test length(instance.scenarios) == 2
            optimizer = optimizer_with_attributes(
                HiGHS.Optimizer,
                "log_to_console" => false,
            )
            model = UnitCommitment.build_model(
                instance = instance,
                optimizer = optimizer,
            )
            UnitCommitment.optimize!(model)
            solution = UnitCommitment.solution(model)
        end
    end
end
