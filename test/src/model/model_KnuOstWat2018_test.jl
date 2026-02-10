# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using HiGHS, JuMP, UnitCommitment

@testfunction model_KnuOstWat2018_test begin
    model =
        build_model(
            UnitCommitment.read(
                fixture("base.json"),
                extensions = [
                    UnitCommitment.ThermalExt(
                        pwl_costs = UnitCommitment.KnuOstWat2018.PwlCosts(),
                    ),
                ],
            ),
            optimizer = HiGHS.Optimizer,
            variable_names = true,
        ).inner

    # eq_segprod_limit_a
    # -------------------------------------------------------------------------
    # g1: min_uptime=1
    @test ("s1", "g1", 1, 1) ∉ keys(model[:eq_segprod_limit_a])

    # g2: min_uptime=3
    @test_constr model[:eq_segprod_limit_a]["s1", "g2", 1, 1] "-47 is_on[g2,1] + segprod[s1,g2,1,1] + 7 switch_off[g2,2] ≤ 0"
    @test_constr model[:eq_segprod_limit_a]["s1", "g2", 1, 2] "-47 is_on[g2,1] + 44 switch_on[g2,1] + segprod[s1,g2,1,2] + 47 switch_off[g2,2] ≤ 0"
    @test_constr model[:eq_segprod_limit_a]["s1", "g2", 1, 3] "-46 is_on[g2,1] + 46 switch_on[g2,1] + segprod[s1,g2,1,3] + 46 switch_off[g2,2] ≤ 0"

    @test_constr model[:eq_segprod_limit_a]["s1", "g2", 2, 1] "-47 is_on[g2,2] + segprod[s1,g2,2,1] + 7 switch_off[g2,3] ≤ 0"
    @test_constr model[:eq_segprod_limit_a]["s1", "g2", 2, 2] "-47 is_on[g2,2] + 44 switch_on[g2,2] + segprod[s1,g2,2,2] + 47 switch_off[g2,3] ≤ 0"
    @test_constr model[:eq_segprod_limit_a]["s1", "g2", 2, 3] "-46 is_on[g2,2] + 46 switch_on[g2,2] + segprod[s1,g2,2,3] + 46 switch_off[g2,3] ≤ 0"

    @test_constr model[:eq_segprod_limit_a]["s1", "g2", 4, 1] "-47 is_on[g2,4] + segprod[s1,g2,4,1] ≤ 0"
    @test_constr model[:eq_segprod_limit_a]["s1", "g2", 4, 2] "-47 is_on[g2,4] + 44 switch_on[g2,4] + segprod[s1,g2,4,2] ≤ 0"
    @test_constr model[:eq_segprod_limit_a]["s1", "g2", 4, 3] "-46 is_on[g2,4] + 46 switch_on[g2,4] + segprod[s1,g2,4,3] ≤ 0"

    # eq_segprod_limit_b, eq_segprod_limit_c
    # -------------------------------------------------------------------------
    # g1: min_uptime=1
    @test_constr model[:eq_segprod_limit_b]["s1", "g1", 1, 1] "-10 is_on[g1,1] + 5 switch_on[g1,1] + segprod[s1,g1,1,1] ≤ 0"
    @test_constr model[:eq_segprod_limit_c]["s1", "g1", 1, 1] "-10 is_on[g1,1] + segprod[s1,g1,1,1] ≤ 0"
    @test_constr model[:eq_segprod_limit_b]["s1", "g1", 1, 2] "-20 is_on[g1,1] + 20 switch_on[g1,1] + segprod[s1,g1,1,2] ≤ 0"
    @test_constr model[:eq_segprod_limit_c]["s1", "g1", 1, 2] "-20 is_on[g1,1] + segprod[s1,g1,1,2] + 10 switch_off[g1,2] ≤ 0"
    @test_constr model[:eq_segprod_limit_b]["s1", "g1", 1, 3] "-5 is_on[g1,1] + 5 switch_on[g1,1] + segprod[s1,g1,1,3] ≤ 0"
    @test_constr model[:eq_segprod_limit_c]["s1", "g1", 1, 3] "-5 is_on[g1,1] + segprod[s1,g1,1,3] + 5 switch_off[g1,2] ≤ 0"

    @test_constr model[:eq_segprod_limit_b]["s1", "g1", 4, 1] "-10 is_on[g1,4] + 5 switch_on[g1,4] + segprod[s1,g1,4,1] ≤ 0"
    @test_constr model[:eq_segprod_limit_b]["s1", "g1", 4, 2] "-20 is_on[g1,4] + 20 switch_on[g1,4] + segprod[s1,g1,4,2] ≤ 0"
    @test_constr model[:eq_segprod_limit_b]["s1", "g1", 4, 3] "-5 is_on[g1,4] + 5 switch_on[g1,4] + segprod[s1,g1,4,3] ≤ 0"
    @test ("s1", "g1", 4, 1) ∉ keys(model[:eq_segprod_limit_c])
    @test ("s1", "g1", 4, 2) ∉ keys(model[:eq_segprod_limit_c])
    @test ("s1", "g1", 4, 3) ∉ keys(model[:eq_segprod_limit_c])

    # g2: min_uptime=3
    @test ("s1", "g2", 1, 1) ∉ keys(model[:eq_segprod_limit_b])
    @test ("s1", "g2", 1, 1) ∉ keys(model[:eq_segprod_limit_c])
end
