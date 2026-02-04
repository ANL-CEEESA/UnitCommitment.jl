# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using HiGHS, JuMP, UnitCommitment

@testfunction model_MorLatRam2013_test begin
    model = UnitCommitment.build_model(
        instance = UnitCommitment.read(fixture("base.json")),
        formulation = UnitCommitment.Formulation(
            ramping = UnitCommitment.MorLatRam2013.Ramping(),
            slimits = UnitCommitment.MorLatRam2013.StartupShutdownLimits(),
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

    # eq_slimit
    # -------------------------------------------------------------------------
    # g2: min_uptime=3
    @test_constr model[:eq_slimit_a]["s1", "g2", 1] "-140 is_on[g2,1] + 90 switch_on[g2,1] + prod_above[s1,g2,1] + reserve[s1,r1,g2,1] + reserve[s1,r2,g2,1] + 100 switch_off[g2,2] ≤ 0"
    @test ("s1", "g2", 1) ∉ keys(model[:eq_slimit_b])
    @test ("s1", "g2", 1) ∉ keys(model[:eq_slimit_c])
    @test ("s1", "g2") ∉ keys(model[:eq_slimit_init])

    # g3: min_uptime=1
    @test ("s1", "g3", 1) ∉ keys(model[:eq_slimit_a])
    @test_constr model[:eq_slimit_b]["s1", "g3", 1] "-100 is_on[g3,1] + 30 switch_on[g3,1] + prod_above[s1,g3,1] + reserve[s1,r1,g3,1] ≤ 0"
    @test_constr model[:eq_slimit_c]["s1", "g3", 1] "-100 is_on[g3,1] + prod_above[s1,g3,1] + reserve[s1,r1,g3,1] + 40 switch_off[g3,2] ≤ 0"
    @test ("s1", "g3") ∉ keys(model[:eq_slimit_init])

    # g4: min_uptime=3, initial_power > shutdown_limit
    @test_constr model[:eq_slimit_a]["s1", "g4", 1] "-67 is_on[g4,1] - 5 switch_on[g4,1] + prod_above[s1,g4,1] + reserve[s1,r1,g4,1] + 70 switch_off[g4,2] ≤ 0"
    @test ("s1", "g4", 1) ∉ keys(model[:eq_slimit_b])
    @test ("s1", "g4", 1) ∉ keys(model[:eq_slimit_c])
    @test_constr model[:eq_slimit_init]["s1", "g4"] "switch_off[g4,1] ≤ 0"
end
