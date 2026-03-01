# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using HiGHS, JuMP, UnitCommitment

@testfunction components_thermal_build_test begin
    model =
        build_model(
            UnitCommitment.read(
                fixture("base.json"),
                extensions = [UnitCommitment.PhaseAngleTransmissionExt()],
            ),
            optimizer = test_optimizer(),
            variable_names = true,
        ).inner

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
    @test model[:reserve_shortfall]["s1", "r2", 1] === 0.0

    # Objective function
    # -------------------------------------------------------------------------
    @test_obj_coef model[:switch_on]["g1", 1] 0.0
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

    # Shutdown costs
    @test_obj_coef model[:switch_off]["g1", 1] 500.0
    @test_obj_coef model[:switch_off]["g2", 1] 750.0
    @test_obj_coef model[:switch_off]["g3", 1] 0.0

    @test_obj_coef model[:invest]["g2", 1] -100.0
    @test_obj_coef model[:invest]["g2", 2] -100.0
    @test_obj_coef model[:invest]["g2", 3] -100.0
    @test_obj_coef model[:invest]["g2", 4] 800.0
    @test_obj_coef model[:reserve_shortfall]["s1", "r1", 1] 1000.0
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

    # eq_min_reserve
    # -------------------------------------------------------------------------
    # r1: amount=100, eligible generators: g2, g3, g4, g5, g6, g7, g8
    @test_constr model[:eq_min_reserve]["s1", "r1", 1] "reserve_shortfall[s1,r1,1] + reserve[s1,r1,g2,1] + reserve[s1,r1,g3,1] + reserve[s1,r1,g4,1] + reserve[s1,r1,g5,1] + reserve[s1,r1,g6,1] + reserve[s1,r1,g7,1] + reserve[s1,r1,g8,1] ≥ 100"
    @test_constr model[:eq_min_reserve]["s1", "r1", 2] "reserve_shortfall[s1,r1,2] + reserve[s1,r1,g2,2] + reserve[s1,r1,g3,2] + reserve[s1,r1,g4,2] + reserve[s1,r1,g5,2] + reserve[s1,r1,g6,2] + reserve[s1,r1,g7,2] + reserve[s1,r1,g8,2] ≥ 100"

    # r2: amount=100, eligible generators: g2 only
    @test_constr model[:eq_min_reserve]["s1", "r2", 1] "reserve[s1,r2,g2,1] ≥ 100"
    @test_constr model[:eq_min_reserve]["s1", "r2", 2] "reserve[s1,r2,g2,2] ≥ 100"

    # r3: amount=50, no eligible generators
    @test_constr model[:eq_min_reserve]["s1", "r3", 1] "reserve_shortfall[s1,r3,1] ≥ 50"
    @test_constr model[:eq_min_reserve]["s1", "r3", 2] "reserve_shortfall[s1,r3,2] ≥ 50"

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

@testfunction components_thermal_build_fixed_status_test begin
    model =
        build_model(
            UnitCommitment.read(
                fixture("case14/fixed.json"),
                extensions = [UnitCommitment.ShiftFactorsTransmissionExt()],
            ),
            optimizer = test_optimizer(),
            variable_names = true,
        ).inner

    # Fixed generators: Float64 constants
    # ---------------------------------------------------------------------
    # g2: commitment_status=[1,1,1,1], initial_status=-8
    @test model[:is_on]["g2", 1] === 1.0
    @test model[:is_on]["g2", 4] === 1.0
    @test model[:switch_on]["g2", 1] === 1.0
    @test model[:switch_on]["g2", 2] === 0.0
    @test model[:switch_off]["g2", 1] === 0.0
    @test model[:switch_off]["g2", 5] === 0.0
    @test model[:startup]["g2", 1, 1] === 0.0
    @test model[:startup]["g2", 1, 2] === 1.0

    # g3: must_run=true, initial_status=-6
    @test model[:is_on]["g3", 1] === 1.0
    @test model[:switch_on]["g3", 1] === 1.0
    @test model[:startup]["g3", 1, 1] === 0.0
    @test model[:startup]["g3", 1, 2] === 1.0
    @test model[:startup]["g3", 1, 3] === 0.0

    # g4: commitment_status=[0,0,0,0], initial_status=-100
    @test model[:is_on]["g4", 1] === 0.0
    @test model[:is_on]["g4", 4] === 0.0
    @test model[:switch_on]["g4", 1] === 0.0
    @test model[:switch_off]["g4", 1] === 0.0

    # g5: commitment_status=[1,1,0,0], initial_status=-100
    @test model[:is_on]["g5", 1] === 1.0
    @test model[:is_on]["g5", 2] === 1.0
    @test model[:is_on]["g5", 3] === 0.0
    @test model[:is_on]["g5", 4] === 0.0
    @test model[:switch_on]["g5", 1] === 1.0
    @test model[:switch_on]["g5", 3] === 0.0
    @test model[:switch_off]["g5", 3] === 1.0
    @test model[:switch_off]["g5", 1] === 0.0

    # Non-fixed generators: binary variables
    # ---------------------------------------------------------------------
    # g1: no must_run, no commitment_status
    @test_binary_var model[:is_on]["g1", 1]
    @test_binary_var model[:switch_on]["g1", 1]
    @test_binary_var model[:switch_off]["g1", 1]
    @test_binary_var model[:startup]["g1", 1, 1]

    # g6: partial commitment_status
    @test_binary_var model[:is_on]["g6", 1]
    @test_binary_var model[:is_on]["g6", 2]

    # Status constraints skipped for fixed generators (g2, g3, g4, g5)
    # ---------------------------------------------------------------------
    for gn in ["g2", "g3", "g4", "g5"]
        for t in 1:4
            @test (gn, t) ∉ keys(model[:eq_binary_link])
            @test (gn, t) ∉ keys(model[:eq_min_uptime])
            @test (gn, t) ∉ keys(model[:eq_min_downtime])
            @test (gn, t) ∉ keys(model[:eq_switch_on_off])
            @test (gn, t) ∉ keys(model[:eq_must_run])
            @test (gn, t) ∉ keys(model[:eq_commitment_status])
        end
        @test (gn, 0) ∉ keys(model[:eq_min_uptime])
        @test (gn, 0) ∉ keys(model[:eq_min_downtime])
    end

    # Status constraints still present for non-fixed generators (g1, g6)
    # ---------------------------------------------------------------------
    for gn in ["g1", "g6"]
        @test (gn, 1) ∈ keys(model[:eq_binary_link])
        @test (gn, 1) ∈ keys(model[:eq_min_uptime])
        @test (gn, 1) ∈ keys(model[:eq_min_downtime])
        @test (gn, 1) ∈ keys(model[:eq_switch_on_off])
    end

    # Startup constraints skipped for fixed generators (g2, g3, g4, g5)
    # ---------------------------------------------------------------------
    for gn in ["g2", "g3", "g4", "g5"]
        for t in 1:4
            @test (gn, t) ∉ keys(model[:eq_startup_choose])
        end
    end

    # Startup constraints still present for non-fixed generators (g1, g6)
    # ---------------------------------------------------------------------
    @test ("g1", 1) ∈ keys(model[:eq_startup_choose])
    @test ("g6", 1) ∈ keys(model[:eq_startup_choose])

    # eq_prod_limit
    # ---------------------------------------------------------------------
    # g2: is_on=1, capacity=140
    @test_constr model[:eq_prod_limit]["s1", "g2", 1] "prod_above[s1,g2,1] + reserve[s1,r1,g2,1] ≤ 140"

    # g4: is_on=0, capacity=67
    @test_constr model[:eq_prod_limit]["s1", "g4", 1] "prod_above[s1,g4,1] + reserve[s1,r1,g4,1] ≤ 0"

    # g6: not fixed
    @test_constr model[:eq_prod_limit]["s1", "g6", 1] "prod_above[s1,g6,1] + reserve[s1,r1,g6,1] ≤ 0"

    # Slimits skipped for no-transition generators (g4: always off)
    # ---------------------------------------------------------------------
    for t in 1:4
        @test ("s1", "g4", t) ∉ keys(model[:eq_slimit_b])
        @test ("s1", "g4", t) ∉ keys(model[:eq_slimit_c])
    end
    @test ("s1", "g4") ∉ keys(model[:eq_slimit_init])

    # Slimits present for fixed generators with transitions
    # ---------------------------------------------------------------------
    # g2: min_uptime=4 > 1, uses eq_slimit_a
    @test ("s1", "g2", 1) ∈ keys(model[:eq_slimit_a])

    # g5: min_uptime=1, uses eq_slimit_b/c
    @test ("s1", "g5", 1) ∈ keys(model[:eq_slimit_b])
    @test ("s1", "g5", 1) ∈ keys(model[:eq_slimit_c])

    # KnuOstWat2018 PWL tightening skipped for no-transition generators
    # ---------------------------------------------------------------------
    for t in 1:4, k in 1:2
        @test ("s1", "g4", t, k) ∉ keys(model[:eq_segprod_limit_b])
    end
    for t in 1:3, k in 1:2
        @test ("s1", "g4", t, k) ∉ keys(model[:eq_segprod_limit_c])
    end

    # KnuOstWat2018 PWL tightening present for fixed generators with transitions
    # ---------------------------------------------------------------------
    # g2: min_uptime=4 > 1, uses eq_segprod_limit_a
    @test ("s1", "g2", 1, 1) ∈ keys(model[:eq_segprod_limit_a])

    # g5: min_uptime=1, uses eq_segprod_limit_b/c
    @test ("s1", "g5", 1, 1) ∈ keys(model[:eq_segprod_limit_b])
    @test ("s1", "g5", 1, 1) ∈ keys(model[:eq_segprod_limit_c])
end
