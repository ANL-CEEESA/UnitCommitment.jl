# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using UnitCommitment, LinearAlgebra, JuMP
USE_GUROBI = (Base.find_package("Gurobi") != nothing)
USE_CBC = !USE_GUROBI
if USE_GUROBI
  using Gurobi
else
  using Cbc
end

NUM_THREADS = 4
LOG_LEVEL = 1

@testset "Model" begin
    @testset "Run" begin
        #instance = UnitCommitment.read_benchmark("test/case14")
        #instance = UnitCommitment.read_benchmark("matpower/case3375wp/2017-02-01")
        instance = UnitCommitment.read_benchmark("matpower/case1888rte/2017-02-01")
        for line in instance.lines, t in 1:4
            line.normal_flow_limit[t] = 10.0
        end
        #for formulation in [UnitCommitment.DefaultFormulation, UnitCommitment.TightFormulation]
        for formulation in [UnitCommitment.TightFormulation]
            @info string("Running test of ", formulation)
            if USE_CBC
              optimizer = optimizer_with_attributes(Cbc.Optimizer, "logLevel" => LOG_LEVEL)
            end
            if USE_GUROBI
              optimizer = optimizer_with_attributes(Gurobi.Optimizer, "Threads" => NUM_THREADS)
            end
            model = build_model(instance=instance,
                                optimizer=optimizer,
                                variable_names=true,
                                components=formulation)

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

            #@show solution
        end # loop over components
    end # end testset Run
end # end test
