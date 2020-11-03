# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using UnitCommitment, LinearAlgebra, Cbc, JuMP

@testset "Model" begin
    @testset "Run" begin
        instance = UnitCommitment.read_benchmark("test/case14")
        for line in instance.lines, t in 1:4
            line.normal_flow_limit[t] = 10.0
        end
        optimizer = optimizer_with_attributes(Cbc.Optimizer, "logLevel" => 0)
        model = build_model(instance=instance,
                            optimizer=optimizer,
                            variable_names=true)

        JuMP.write_to_file(model.mip, "test.mps")

        # Optimize and retrieve solution
        UnitCommitment.optimize!(model)
        solution = get_solution(model)
        
        # Verify solution
        @test UnitCommitment.validate(instance, solution)

        # Reoptimize with fixed solution
        UnitCommitment.fix!(model, solution)
        UnitCommitment.optimize!(model)
        @test UnitCommitment.validate(instance, solution)
    end
end
