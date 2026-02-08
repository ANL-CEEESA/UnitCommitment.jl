# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using HiGHS, JuMP, UnitCommitment

@testfunction model_base_thermal_test begin
    model = UnitCommitment.build_model(
        instance = UnitCommitment.read(fixture("base.json")),
        formulation = UnitCommitment.BaseFormulation,
        optimizer = HiGHS.Optimizer,
        variable_names = true,
    )

    # Decision variables
    # -------------------------------------------------------------------------
    @test_binary_var model[:is_on]["g1", 1]
    @test_binary_var model[:switch_on]["g1", 1]
    @test_binary_var model[:switch_off]["g1", 1]
    @test_binary_var model[:startup]["g1", 1, 1]
    @test ("g1", 1) ∉ keys(model[:invest])
    @test_binary_var model[:invest]["g2", 1]
    @test_continuous_var model[:prod_above]["s1", "g1", 1] lb = 0
    @test_continuous_var model[:segprod]["s1", "g1", 1, 1] lb = 0 ub = 10
    @test_continuous_var model[:segprod]["s1", "g1", 1, 2] lb = 0 ub = 20
    @test_continuous_var model[:segprod]["s1", "g1", 1, 3] lb = 0 ub = 5
    @test_continuous_var model[:reserve]["s1", "r1", "g2", 1] lb = 0
    @test_continuous_var model[:reserve]["s1", "r2", "g2", 1] lb = 0
    @test_continuous_var model[:reserve]["s1", "r1", "g3", 1] lb = 0
    @test ("s1", "r2", "g3", 1) ∉ keys(model[:reserve])
    @test_continuous_var model[:reserve_shortfall]["s1", "r1", 1] lb = 0
    @test_continuous_var model[:reserve_shortfall]["s1", "r2", 1] lb = 0 ub = 0

    # Objective function
    # -------------------------------------------------------------------------
    @test_obj_coef model[:switch_on]["g1", 1] 0.0
    @test_obj_coef model[:switch_off]["g1", 1] 0.0
    @test_obj_coef model[:prod_above]["s1", "g1", 1] 0.0
    @test_obj_coef model[:reserve]["s1", "r1", "g2", 1] 0.0
    @test_obj_coef model[:is_on]["g1", 1] 1400.0
    @test_obj_coef model[:is_on]["g2", 1] 0.0
    @test_obj_coef model[:is_on]["g3", 1] 0.0
    @test_obj_coef model[:segprod]["s1", "g1", 1, 1] 20.0
    @test_obj_coef model[:segprod]["s1", "g1", 1, 2] 30.0
    @test_obj_coef model[:segprod]["s1", "g1", 1, 3] 40.0
    @test_obj_coef model[:segprod]["s1", "g2", 1, 1] 48.0
    @test_obj_coef model[:segprod]["s1", "g2", 1, 2] 52.71
    @test_obj_coef model[:segprod]["s1", "g2", 1, 3] 57.87
    @test_obj_coef model[:startup]["g1", 1, 1] 1000.0
    @test_obj_coef model[:startup]["g1", 1, 2] 1500.0
    @test_obj_coef model[:startup]["g1", 1, 3] 2000.0
    @test_obj_coef model[:startup]["g2", 1, 1] 3000.0
    @test_obj_coef model[:startup]["g2", 1, 2] 4000.0
    @test_obj_coef model[:invest]["g2", 1] -100.0
    @test_obj_coef model[:invest]["g2", 2] -100.0
    @test_obj_coef model[:invest]["g2", 3] -100.0
    @test_obj_coef model[:invest]["g2", 4] 800.0
    @test_obj_coef model[:reserve_shortfall]["s1", "r1", 1] 1000.0
    @test_obj_coef model[:reserve_shortfall]["s1", "r2", 1] 0.0

    # eq_must_run
    # -------------------------------------------------------------------------
    @test_constr model[:eq_must_run]["g1", 1] "is_on[g1,1] ≥ 1"
    @test_constr model[:eq_must_run]["g1", 2] "is_on[g1,2] ≥ 1"
    @test ("g2", 1) ∉ keys(model[:eq_must_run])

    # eq_commitment_status
    # -------------------------------------------------------------------------
    @test_constr model[:eq_commitment_status]["g4", 1] "is_on[g4,1] = 1"
    @test_constr model[:eq_commitment_status]["g4", 2] "is_on[g4,2] = 0"
    @test ("g4", 3) ∉ keys(model[:eq_commitment_status])
    @test_constr model[:eq_commitment_status]["g4", 4] "is_on[g4,4] = 1"
    @test ("g1", 1) ∉ keys(model[:eq_commitment_status])

    # eq_min_uptime
    # -------------------------------------------------------------------------
    # min_uptime=1, initial_status=-100
    @test ("g1", 0) ∉ keys(model[:eq_min_uptime])
    @test_constr model[:eq_min_uptime]["g1", 1] "-is_on[g1,1] + switch_on[g1,1] ≤ 0"
    @test_constr model[:eq_min_uptime]["g1", 2] "-is_on[g1,2] + switch_on[g1,2] ≤ 0"
    @test_constr model[:eq_min_uptime]["g1", 3] "-is_on[g1,3] + switch_on[g1,3] ≤ 0"
    @test_constr model[:eq_min_uptime]["g1", 4] "-is_on[g1,4] + switch_on[g1,4] ≤ 0"

    # min_uptime=3, initial_status=-2
    @test ("g2", 0) ∉ keys(model[:eq_min_uptime])
    @test_constr model[:eq_min_uptime]["g2", 1] "-is_on[g2,1] + switch_on[g2,1] ≤ 0"
    @test_constr model[:eq_min_uptime]["g2", 2] "switch_on[g2,1] - is_on[g2,2] + switch_on[g2,2] ≤ 0"
    @test_constr model[:eq_min_uptime]["g2", 3] "switch_on[g2,1] + switch_on[g2,2] - is_on[g2,3] + switch_on[g2,3] ≤ 0"
    @test_constr model[:eq_min_uptime]["g2", 4] "switch_on[g2,2] + switch_on[g2,3] - is_on[g2,4] + switch_on[g2,4] ≤ 0"

    # min_uptime=3, initial_status=2
    @test_constr model[:eq_min_uptime]["g4", 0] "switch_off[g4,1] = 0"
    @test_constr model[:eq_min_uptime]["g4", 1] "-is_on[g4,1] + switch_on[g4,1] ≤ 0"
    @test_constr model[:eq_min_uptime]["g4", 2] "switch_on[g4,1] - is_on[g4,2] + switch_on[g4,2] ≤ 0"
    @test_constr model[:eq_min_uptime]["g4", 3] "switch_on[g4,1] + switch_on[g4,2] - is_on[g4,3] + switch_on[g4,3] ≤ 0"
    @test_constr model[:eq_min_uptime]["g4", 4] "switch_on[g4,2] + switch_on[g4,3] - is_on[g4,4] + switch_on[g4,4] ≤ 0"

    # min_uptime=3, initial_status=3
    @test_constr model[:eq_min_uptime]["g5", 0] "0 = 0"

    # min_uptime=10, initial_status=3
    @test_constr model[:eq_min_uptime]["g6", 0] "switch_off[g6,1] + switch_off[g6,2] + switch_off[g6,3] + switch_off[g6,4] = 0"

    # eq_min_downtime
    # -------------------------------------------------------------------------
    # g1: min_uptime=1, initial_status=-100
    @test_constr model[:eq_min_downtime]["g1", 0] "0 = 0"
    @test_constr model[:eq_min_downtime]["g1", 1] "is_on[g1,1] + switch_off[g1,1] ≤ 1"
    @test_constr model[:eq_min_downtime]["g1", 2] "is_on[g1,2] + switch_off[g1,2] ≤ 1"
    @test_constr model[:eq_min_downtime]["g1", 3] "is_on[g1,3] + switch_off[g1,3] ≤ 1"
    @test_constr model[:eq_min_downtime]["g1", 4] "is_on[g1,4] + switch_off[g1,4] ≤ 1"

    # g2: min_downtime=3, initial_status=-2
    @test_constr model[:eq_min_downtime]["g2", 0] "switch_on[g2,1] = 0"
    @test_constr model[:eq_min_downtime]["g2", 1] "is_on[g2,1] + switch_off[g2,1] ≤ 1"
    @test_constr model[:eq_min_downtime]["g2", 2] "switch_off[g2,1] + is_on[g2,2] + switch_off[g2,2] ≤ 1"
    @test_constr model[:eq_min_downtime]["g2", 3] "switch_off[g2,1] + switch_off[g2,2] + is_on[g2,3] + switch_off[g2,3] ≤ 1"
    @test_constr model[:eq_min_downtime]["g2", 4] "switch_off[g2,2] + switch_off[g2,3] + is_on[g2,4] + switch_off[g2,4] ≤ 1"

    # g4: min_downtime=4, initial_status=2
    @test ("g4", 0) ∉ keys(model[:eq_min_downtime])
    @test_constr model[:eq_min_downtime]["g4", 1] "is_on[g4,1] + switch_off[g4,1] ≤ 1"
    @test_constr model[:eq_min_downtime]["g4", 2] "switch_off[g4,1] + is_on[g4,2] + switch_off[g4,2] ≤ 1"
    @test_constr model[:eq_min_downtime]["g4", 3] "switch_off[g4,1] + switch_off[g4,2] + is_on[g4,3] + switch_off[g4,3] ≤ 1"
    @test_constr model[:eq_min_downtime]["g4", 4] "switch_off[g4,1] + switch_off[g4,2] + switch_off[g4,3] + is_on[g4,4] + switch_off[g4,4] ≤ 1"

    # g7: min_downtime=3, initial_status=-3
    @test_constr model[:eq_min_downtime]["g7", 0] "0 = 0"

    # g8: min_downtime=10, initial_status=-3
    @test_constr model[:eq_min_downtime]["g8", 0] "switch_on[g8,1] + switch_on[g8,2] + switch_on[g8,3] + switch_on[g8,4] = 0"

    # eq_startup_choose
    # -------------------------------------------------------------------------
    @test_constr model[:eq_startup_choose]["g1", 1] "switch_on[g1,1] - startup[g1,1,1] - startup[g1,1,2] - startup[g1,1,3] = 0"
    @test_constr model[:eq_startup_choose]["g1", 2] "switch_on[g1,2] - startup[g1,2,1] - startup[g1,2,2] - startup[g1,2,3] = 0"
    @test_constr model[:eq_startup_choose]["g2", 1] "switch_on[g2,1] - startup[g2,1,1] - startup[g2,1,2] = 0"

    # eq_startup_restrict
    # -------------------------------------------------------------------------
    # g1: delays [1, 2, 3], initial_status=-100
    @test_constr model[:eq_startup_restrict]["g1", 1, 1] "startup[g1,1,1] ≤ 0"
    @test_constr model[:eq_startup_restrict]["g1", 1, 2] "startup[g1,1,2] ≤ 0"
    @test ("g1", 1, 3) ∉ keys(model[:eq_startup_restrict])
    @test_constr model[:eq_startup_restrict]["g1", 2, 1] "-switch_off[g1,1] + startup[g1,2,1] ≤ 0"
    @test_constr model[:eq_startup_restrict]["g1", 2, 2] "startup[g1,2,2] ≤ 0"
    @test_constr model[:eq_startup_restrict]["g1", 3, 1] "-switch_off[g1,2] + startup[g1,3,1] ≤ 0"
    @test_constr model[:eq_startup_restrict]["g1", 3, 2] "-switch_off[g1,1] + startup[g1,3,2] ≤ 0"
    @test_constr model[:eq_startup_restrict]["g1", 4, 1] "-switch_off[g1,3] + startup[g1,4,1] ≤ 0"
    @test_constr model[:eq_startup_restrict]["g1", 4, 2] "-switch_off[g1,2] + startup[g1,4,2] ≤ 0"

    # g2: delays [1, 4], initial_status=-2
    @test_constr model[:eq_startup_restrict]["g2", 1, 1] "startup[g2,1,1] ≤ 1"
    @test_constr model[:eq_startup_restrict]["g2", 2, 1] "-switch_off[g2,1] + startup[g2,2,1] ≤ 1"
    @test_constr model[:eq_startup_restrict]["g2", 3, 1] "-switch_off[g2,1] - switch_off[g2,2] + startup[g2,3,1] ≤ 0"
    @test_constr model[:eq_startup_restrict]["g2", 4, 1] "-switch_off[g2,1] - switch_off[g2,2] - switch_off[g2,3] + startup[g2,4,1] ≤ 0"

    # g3: delays [1, 4, 8], initial_status=-6
    @test_constr model[:eq_startup_restrict]["g3", 1, 1] "startup[g3,1,1] ≤ 0"
    @test_constr model[:eq_startup_restrict]["g3", 1, 2] "startup[g3,1,2] ≤ 1"
    @test_constr model[:eq_startup_restrict]["g3", 2, 1] "-switch_off[g3,1] + startup[g3,2,1] ≤ 0"
    @test_constr model[:eq_startup_restrict]["g3", 2, 2] "startup[g3,2,2] ≤ 1"
    @test_constr model[:eq_startup_restrict]["g3", 3, 1] "-switch_off[g3,1] - switch_off[g3,2] + startup[g3,3,1] ≤ 0"
    @test_constr model[:eq_startup_restrict]["g3", 3, 2] "startup[g3,3,2] ≤ 0"
    @test_constr model[:eq_startup_restrict]["g3", 4, 2] "startup[g3,4,2] ≤ 0"

    # g9: delays [1, 3, 5], initial_status=-2
    @test_constr model[:eq_startup_restrict]["g9", 1, 1] "startup[g9,1,1] ≤ 1"
    @test_constr model[:eq_startup_restrict]["g9", 1, 2] "startup[g9,1,2] ≤ 0"
    @test_constr model[:eq_startup_restrict]["g9", 2, 1] "-switch_off[g9,1] + startup[g9,2,1] ≤ 0"
    @test_constr model[:eq_startup_restrict]["g9", 2, 2] "startup[g9,2,2] ≤ 1"
    @test_constr model[:eq_startup_restrict]["g9", 3, 1] "-switch_off[g9,1] - switch_off[g9,2] + startup[g9,3,1] ≤ 0"
    @test_constr model[:eq_startup_restrict]["g9", 3, 2] "startup[g9,3,2] ≤ 1"
    @test_constr model[:eq_startup_restrict]["g9", 4, 1] "-switch_off[g9,2] - switch_off[g9,3] + startup[g9,4,1] ≤ 0"
    @test_constr model[:eq_startup_restrict]["g9", 4, 2] "-switch_off[g9,1] + startup[g9,4,2] ≤ 0"

    # eq_binary_link
    # -------------------------------------------------------------------------
    # g1: initial_status=-100 (initially off)
    @test_constr model[:eq_binary_link]["g1", 1] "is_on[g1,1] - switch_on[g1,1] + switch_off[g1,1] = 0"
    @test_constr model[:eq_binary_link]["g1", 2] "-is_on[g1,1] + is_on[g1,2] - switch_on[g1,2] + switch_off[g1,2] = 0"
    @test_constr model[:eq_binary_link]["g1", 3] "-is_on[g1,2] + is_on[g1,3] - switch_on[g1,3] + switch_off[g1,3] = 0"
    @test_constr model[:eq_binary_link]["g1", 4] "-is_on[g1,3] + is_on[g1,4] - switch_on[g1,4] + switch_off[g1,4] = 0"

    # g4: initial_status=2 (initially on)
    @test_constr model[:eq_binary_link]["g4", 1] "is_on[g4,1] - switch_on[g4,1] + switch_off[g4,1] = 1"
    @test_constr model[:eq_binary_link]["g4", 2] "-is_on[g4,1] + is_on[g4,2] - switch_on[g4,2] + switch_off[g4,2] = 0"
    @test_constr model[:eq_binary_link]["g4", 3] "-is_on[g4,2] + is_on[g4,3] - switch_on[g4,3] + switch_off[g4,3] = 0"
    @test_constr model[:eq_binary_link]["g4", 4] "-is_on[g4,3] + is_on[g4,4] - switch_on[g4,4] + switch_off[g4,4] = 0"

    # eq_switch_on_off
    # -------------------------------------------------------------------------
    @test_constr model[:eq_switch_on_off]["g1", 1] "switch_on[g1,1] + switch_off[g1,1] ≤ 1"
    @test_constr model[:eq_switch_on_off]["g1", 2] "switch_on[g1,2] + switch_off[g1,2] ≤ 1"
    @test_constr model[:eq_switch_on_off]["g4", 1] "switch_on[g4,1] + switch_off[g4,1] ≤ 1"
    @test_constr model[:eq_switch_on_off]["g4", 2] "switch_on[g4,2] + switch_off[g4,2] ≤ 1"

    # eq_prod_limit
    # -------------------------------------------------------------------------
    # g1: no reserves, max_power=135, min_power=100, capacity=35
    @test_constr model[:eq_prod_limit]["s1", "g1", 1] "-35 is_on[g1,1] + prod_above[s1,g1,1] ≤ 0"
    @test_constr model[:eq_prod_limit]["s1", "g1", 2] "-35 is_on[g1,2] + prod_above[s1,g1,2] ≤ 0"

    # g2: reserves r1 and r2, max_power=140, min_power=0, capacity=140
    @test_constr model[:eq_prod_limit]["s1", "g2", 1] "-140 is_on[g2,1] + prod_above[s1,g2,1] + reserve[s1,r1,g2,1] + reserve[s1,r2,g2,1] ≤ 0"
    @test_constr model[:eq_prod_limit]["s1", "g2", 2] "-140 is_on[g2,2] + prod_above[s1,g2,2] + reserve[s1,r1,g2,2] + reserve[s1,r2,g2,2] ≤ 0"

    # g10: no reserves, max_power=min_power=50, capacity=0
    @test_constr model[:eq_prod_limit]["s1", "g10", 1] "prod_above[s1,g10,1] ≤ 0"
    @test_constr model[:eq_prod_limit]["s1", "g10", 2] "prod_above[s1,g10,2] ≤ 0"

    # eq_invest_link
    # -------------------------------------------------------------------------
    # g1: no investment cost, constraint should not exist
    @test ("g1", 1) ∉ keys(model[:eq_invest_link])

    # g2: positive investment cost
    @test_constr model[:eq_invest_link]["g2", 1] "is_on[g2,1] - invest[g2,1] ≤ 0"
    @test_constr model[:eq_invest_link]["g2", 2] "is_on[g2,2] - invest[g2,2] ≤ 0"
    @test_constr model[:eq_invest_link]["g2", 3] "is_on[g2,3] - invest[g2,3] ≤ 0"
    @test_constr model[:eq_invest_link]["g2", 4] "is_on[g2,4] - invest[g2,4] ≤ 0"

    # eq_invest_nondec
    # -------------------------------------------------------------------------
    # g1: no investment cost, constraint should not exist
    @test ("g1", 2) ∉ keys(model[:eq_invest_nondec])

    # g2: positive investment cost, enforced for t >= 2
    @test ("g2", 1) ∉ keys(model[:eq_invest_nondec])
    @test_constr model[:eq_invest_nondec]["g2", 2] "invest[g2,1] - invest[g2,2] ≤ 0"
    @test_constr model[:eq_invest_nondec]["g2", 3] "invest[g2,2] - invest[g2,3] ≤ 0"
    @test_constr model[:eq_invest_nondec]["g2", 4] "invest[g2,3] - invest[g2,4] ≤ 0"

    # net_injection
    # -------------------------------------------------------------------------
    ni = model[:net_injection]

    # g1: bus=b1, min_power=100
    @test_aff_expr ni["s1", "b1", 1] model[:prod_above]["s1", "g1", 1] 1.0
    @test_aff_expr ni["s1", "b1", 1] model[:is_on]["g1", 1] 100.0
    @test_aff_expr ni["s1", "b1", 4] model[:prod_above]["s1", "g1", 4] 1.0
    @test_aff_expr ni["s1", "b1", 4] model[:is_on]["g1", 4] 100.0

    # g2: bus=b2, min_power=0
    @test_aff_expr ni["s1", "b2", 1] model[:prod_above]["s1", "g2", 1] 1.0
    @test_aff_expr ni["s1", "b2", 1] model[:is_on]["g2", 1] 0.0

    # g3: bus=b3, min_power=0
    @test_aff_expr ni["s1", "b3", 1] model[:prod_above]["s1", "g3", 1] 1.0
    @test_aff_expr ni["s1", "b3", 1] model[:is_on]["g3", 1] 0.0
end
