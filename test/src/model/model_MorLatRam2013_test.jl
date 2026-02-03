# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using HiGHS, JuMP, UnitCommitment

@testfunction model_MorLatRam2013_test begin
    model = UnitCommitment.build_model(
        instance = UnitCommitment.read(fixture("base.json")),
        formulation = UnitCommitment.Formulation(
            ramping = UnitCommitment.MorLatRam2013.Ramping(),
        ),
        optimizer = HiGHS.Optimizer,
        variable_names = true,
    )

    # eq_ramp_up
    # -------------------------------------------------------------------------
    @test_constr model[:eq_ramp_up]["s1", "g4", 1] "prod_above[s1,g4,1] + reserve[s1,r1,g4,1] ≤ 87"
    @test_constr model[:eq_ramp_up]["s1", "g4", 2] "-prod_above[s1,g4,1] + prod_above[s1,g4,2] + reserve[s1,r1,g4,2] ≤ 70"
    @test_constr model[:eq_ramp_up]["s1", "g4", 3] "-prod_above[s1,g4,2] + prod_above[s1,g4,3] + reserve[s1,r1,g4,3] ≤ 70"
    @test_constr model[:eq_ramp_up]["s1", "g4", 4] "-prod_above[s1,g4,3] + prod_above[s1,g4,4] + reserve[s1,r1,g4,4] ≤ 70"

    @test ("s1", "g1", 1) ∉ keys(model[:eq_ramp_up])
    @test_constr model[:eq_ramp_up]["s1", "g1", 2] "-prod_above[s1,g1,1] + prod_above[s1,g1,2] ≤ 70"
    @test_constr model[:eq_ramp_up]["s1", "g1", 3] "-prod_above[s1,g1,2] + prod_above[s1,g1,3] ≤ 70"
    @test_constr model[:eq_ramp_up]["s1", "g1", 4] "-prod_above[s1,g1,3] + prod_above[s1,g1,4] ≤ 70"

    # eq_ramp_down
    # -------------------------------------------------------------------------
    @test_constr model[:eq_ramp_down]["s1", "g4", 1] "-prod_above[s1,g4,1] ≤ 43"
    @test_constr model[:eq_ramp_down]["s1", "g4", 2] "prod_above[s1,g4,1] - prod_above[s1,g4,2] ≤ 60"
    @test_constr model[:eq_ramp_down]["s1", "g4", 3] "prod_above[s1,g4,2] - prod_above[s1,g4,3] ≤ 60"
    @test_constr model[:eq_ramp_down]["s1", "g4", 4] "prod_above[s1,g4,3] - prod_above[s1,g4,4] ≤ 60"

    @test ("s1", "g1", 1) ∉ keys(model[:eq_ramp_down])
    @test_constr model[:eq_ramp_down]["s1", "g1", 2] "prod_above[s1,g1,1] - prod_above[s1,g1,2] ≤ 60"
    @test_constr model[:eq_ramp_down]["s1", "g1", 3] "prod_above[s1,g1,2] - prod_above[s1,g1,3] ≤ 60"
    @test_constr model[:eq_ramp_down]["s1", "g1", 4] "prod_above[s1,g1,3] - prod_above[s1,g1,4] ≤ 60"
end
