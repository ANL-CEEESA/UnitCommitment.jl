# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using UnitCommitment
using JuMP
using HiGHS
using JSON

function storage_optimization_test()
    @testset "storage_optimization" begin
        instance =
            UnitCommitment.read(fixture("case24-iberian-storage.json.gz"))
        model = UnitCommitment.build_model(
            instance = instance,
            optimizer = HiGHS.Optimizer,
            variable_names = true,
        )
        set_silent(model)
        UnitCommitment.optimize!(model)
        solution = UnitCommitment.solution(model)
        # results must be valid 
        @test UnitCommitment.validate(instance, solution)
        # storages are being used 
        charging_rates = solution["Storage charging rates (MW)"]
        discharging_rates = solution["Storage discharging rates (MW)"]
        @test sum(charging_rates["su1"]) > 0
        @test sum(charging_rates["su2"]) > 0
        @test sum(discharging_rates["su1"]) > 0
        @test sum(discharging_rates["su2"]) > 0
    end
end
