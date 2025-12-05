# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using UnitCommitment, HiGHS, JuMP

function regression_test()
    @testset "GitHub Issue #57" begin
        instance = UnitCommitment.read(fixture("issue-0057.json.gz"))
        model = UnitCommitment.build_model(
            instance = instance,
            optimizer = HiGHS.Optimizer,
        )
        JuMP.set_silent(model)
        UnitCommitment.optimize!(model)
        solution = UnitCommitment.solution(model)
        @test solution["Thermal production (MW)"]["gen_524d4c85"][1] == 90.0
    end
end
