# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using UnitCommitment, Cbc, HiGHS, JuMP
import UnitCommitment: AELMP

@testset "aelmp" begin
    path = "$FIXTURES/aelmp_simple.json.gz"
    # model has to be solved first
    instance = UnitCommitment.read(path)
    model = UnitCommitment.build_model(
        instance = instance,
        optimizer = Cbc.Optimizer,
        variable_names = true,
    )
    JuMP.set_silent(model)
    UnitCommitment.optimize!(model)

    # policy 1: allow offlines; consider startups
    aelmp_1 =
        UnitCommitment.compute_lmp(model, AELMP(), optimizer = HiGHS.Optimizer)
    @test aelmp_1["B1", 1] ≈ 231.7 atol = 0.1

    # policy 2: do not allow offlines; but consider startups
    aelmp_2 = UnitCommitment.compute_lmp(
        model,
        AELMP(
            allow_offline_participation = false,
            consider_startup_costs = true,
        ),
        optimizer = HiGHS.Optimizer,
    )
    @test aelmp_2["B1", 1] ≈ 274.3 atol = 0.1
end
