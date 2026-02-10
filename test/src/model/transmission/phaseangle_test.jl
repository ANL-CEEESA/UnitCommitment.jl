# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using HiGHS, JuMP, UnitCommitment

@testfunction model_transmission_phaseangle_test begin
    model = UnitCommitment.build_model(
        instance = UnitCommitment.read(
            fixture("base.json"),
            extensions = [
                UnitCommitment.PhaseAngleTransmissionExt(
                    phase_angle_limit = pi,
                    bigM = 1e6,
                ),
            ],
        ),
        optimizer = HiGHS.Optimizer,
        variable_names = true,
    )

    # Decision variables
    # -------------------------------------------------------------------------
    @test value(fix_value(model[:theta]["s1", "b1", 1])) ≈ 0.0
    @test_continuous_var model[:theta]["s1", "b2", 1] lb = -pi ub = pi
    @test_continuous_var model[:theta]["s1", "b3", 1] lb = -pi ub = pi
    @test_continuous_var model[:flow]["s1", "l1", 1]
    @test_continuous_var model[:flow]["s1", "l21", 1]
    @test_continuous_var model[:flow]["s1", "l22", 1]
    @test_continuous_var model[:overflow]["s1", "l1", 1] lb = 0
    @test_continuous_var model[:overflow]["s1", "l21", 1] lb = 0
    @test_continuous_var model[:overflow]["s1", "l22", 1] lb = 0

    # Investment variables
    # # l1: no investment (variable should not exist for t=1)
    @test ("l1", 1) ∉ keys(model[:invest])

    # l21: investment line with max_copy=3
    @test model[:invest]["l21", 0] == 0.0
    @test_integer_var model[:invest]["l21", 1] lb = 0 ub = 3
    @test_integer_var model[:invest]["l21", 2] lb = 0 ub = 3

    # l22: investment line with max_copy=1
    @test model[:invest]["l22", 0] == 0.0
    @test_integer_var model[:invest]["l22", 1] lb = 0 ub = 1
    @test_integer_var model[:invest]["l22", 2] lb = 0 ub = 1

    # Objective function
    # -------------------------------------------------------------------------

    # Overflow penalties
    @test_obj_coef model[:overflow]["s1", "l1", 1] 1000.0
    @test_obj_coef model[:overflow]["s1", "l21", 1] 5000.0
    @test_obj_coef model[:overflow]["s1", "l22", 1] 6000.0

    # Investment costs (with investment_cost_weight = 0.1)
    # l21: costs = [1000, 2000, 3000, 4000]
    @test_obj_coef model[:invest]["l21", 1] -100.0
    @test_obj_coef model[:invest]["l21", 2] -100.0
    @test_obj_coef model[:invest]["l21", 3] -100.0
    @test_obj_coef model[:invest]["l21", 4] 400.0

    # l22: cost = 5000, same for all periods
    @test_obj_coef model[:invest]["l22", 1] 0.0
    @test_obj_coef model[:invest]["l22", 2] 0.0
    @test_obj_coef model[:invest]["l22", 3] 0.0
    @test_obj_coef model[:invest]["l22", 4] 500.0

    # eq_dc_flow
    # -------------------------------------------------------------------------

    # l1: existing line (no investment), susceptance = 29.497
    @test_constr model[:eq_dc_flow]["s1", "l1", 1] "-29.497 theta[s1,b1,1] + 29.497 theta[s1,b2,1] + flow[s1,l1,1] = 0"
    @test ("s1", "l1", 1) ∉ keys(model[:eq_dc_flow_bigm_ub])

    # l21: investment line with max_copy=3, susceptance = 10.0
    @test_constr model[:eq_dc_flow]["s1", "l21", 1] "-10 invest[l21,1]*theta[s1,b1,1] + 10 invest[l21,1]*theta[s1,b3,1] + flow[s1,l21,1] = 0"
    @test ("s1", "l21", 1) ∉ keys(model[:eq_dc_flow_bigm_ub])

    # # l22: investment line with max_copy=1, susceptance = 15.0, bigM = 1e6
    @test ("s1", "l22", 1) ∉ keys(model[:eq_dc_flow])
    @test_constr model[:eq_dc_flow_bigm_ub]["s1", "l22", 1] "1000000 invest[l22,1] - 15 theta[s1,b2,1] + 15 theta[s1,b6,1] + flow[s1,l22,1] ≤ 1000000"
    @test_constr model[:eq_dc_flow_bigm_lb]["s1", "l22", 1] "-1000000 invest[l22,1] - 15 theta[s1,b2,1] + 15 theta[s1,b6,1] + flow[s1,l22,1] ≥ -1000000"

    # eq_flow_limit_ub and eq_flow_limit_lb
    # -------------------------------------------------------------------------
    # # l1: existing line, normal_flow_limit = 300.0
    @test_constr model[:eq_flow_limit_ub]["s1", "l1", 1] "-overflow[s1,l1,1] + flow[s1,l1,1] ≤ 300"
    @test_constr model[:eq_flow_limit_lb]["s1", "l1", 1] "overflow[s1,l1,1] + flow[s1,l1,1] ≥ -300"

    # # l21: investment line with max_copy=3, normal_flow_limit = 100.0
    @test_constr model[:eq_flow_limit_ub]["s1", "l21", 1] "-100 invest[l21,1] - overflow[s1,l21,1] + flow[s1,l21,1] ≤ 0"
    @test_constr model[:eq_flow_limit_lb]["s1", "l21", 1] "100 invest[l21,1] + overflow[s1,l21,1] + flow[s1,l21,1] ≥ 0"

    # l22: investment line with max_copy=1, normal_flow_limit = 150.0
    @test_constr model[:eq_flow_limit_ub]["s1", "l22", 1] "-150 invest[l22,1] - overflow[s1,l22,1] + flow[s1,l22,1] ≤ 0"
    @test_constr model[:eq_flow_limit_lb]["s1", "l22", 1] "150 invest[l22,1] + overflow[s1,l22,1] + flow[s1,l22,1] ≥ 0"

    # eq_invest_nondec
    # -------------------------------------------------------------------------
    # l1: no investment, constraint should not exist
    @test ("l1", 2) ∉ keys(model[:eq_invest_nondec])

    # l21: investment line, enforced for t >= 2
    @test ("l21", 1) ∉ keys(model[:eq_invest_nondec])
    @test_constr model[:eq_invest_nondec]["l21", 2] "invest[l21,1] - invest[l21,2] ≤ 0"
    @test_constr model[:eq_invest_nondec]["l21", 3] "invest[l21,2] - invest[l21,3] ≤ 0"
    @test_constr model[:eq_invest_nondec]["l21", 4] "invest[l21,3] - invest[l21,4] ≤ 0"

    # eq_nodal_balance
    # -------------------------------------------------------------------------
    @test_constr model[:eq_nodal_balance]["s1", "b1", 1] "100 is_on[g1,1] + prod_above[s1,g1,1] + flow[s1,l1,1] + flow[s1,l2,1] + flow[s1,l21,1] = 0"
    @test_constr model[:eq_nodal_balance]["s1", "b2", 1] "prod_above[s1,g2,1] - flow[s1,l1,1] + flow[s1,l3,1] + flow[s1,l4,1] + flow[s1,l5,1] + flow[s1,l22,1] = 26.01527"
    @test_constr model[:eq_nodal_balance]["s1", "b3", 1] "prod_above[s1,g3,1] - flow[s1,l3,1] + flow[s1,l6,1] - flow[s1,l21,1] = 112.93263"
end
