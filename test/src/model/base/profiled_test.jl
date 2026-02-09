# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using HiGHS, JuMP, UnitCommitment

@testfunction model_base_profiled_test begin
    model = UnitCommitment.build_model(
        instance = UnitCommitment.read(
            fixture("base.json"),
            extensions = [UnitCommitment.ProfiledUnitsExt()],
        ),
        formulation = UnitCommitment.BaseFormulation,
        optimizer = HiGHS.Optimizer,
        variable_names = true,
    )

    # Decision variables
    # -------------------------------------------------------------------------
    # p1: no investment
    @test_continuous_var model[:prod]["s1", "p1", 1] lb = 10.0 ub = 100.0
    @test_continuous_var model[:prod]["s1", "p1", 4] lb = 10.0 ub = 100.0
    @test ("p1", 1) ∉ keys(model[:invest])

    # p2: with investment
    @test_continuous_var model[:prod]["s1", "p2", 1] lb = 5.0 ub = 80.0
    @test_continuous_var model[:prod]["s1", "p2", 4] lb = 5.0 ub = 80.0
    @test_binary_var model[:invest]["p2", 1]
    @test_binary_var model[:invest]["p2", 4]

    # Objective function
    # -------------------------------------------------------------------------
    @test_obj_coef model[:prod]["s1", "p1", 1] 50.0
    @test_obj_coef model[:prod]["s1", "p2", 1] 30.0

    # p2: invest costs [1000, 2000, 3000, 4000], weight 0.1
    @test_obj_coef model[:invest]["p2", 1] -100.0
    @test_obj_coef model[:invest]["p2", 2] -100.0
    @test_obj_coef model[:invest]["p2", 3] -100.0
    @test_obj_coef model[:invest]["p2", 4] 400.0

    # eq_invest_nondec (profiled)
    # -------------------------------------------------------------------------
    # p1: no investment cost, constraint should not exist
    @test ("p1", 2) ∉ keys(model[:eq_invest_nondec])

    # p2: positive investment cost, enforced for t >= 2
    @test ("p2", 1) ∉ keys(model[:eq_invest_nondec])
    @test_constr model[:eq_invest_nondec]["p2", 2] "invest[p2,1] - invest[p2,2] ≤ 0"
    @test_constr model[:eq_invest_nondec]["p2", 3] "invest[p2,2] - invest[p2,3] ≤ 0"
    @test_constr model[:eq_invest_nondec]["p2", 4] "invest[p2,3] - invest[p2,4] ≤ 0"

    # eq_invest_prod_ub
    # -------------------------------------------------------------------------
    # p1: no investment cost, constraint should not exist
    @test ("s1", "p1", 1) ∉ keys(model[:eq_invest_prod_ub])

    # p2: production upper bounded by capacity when invested
    @test_constr model[:eq_invest_prod_ub]["s1", "p2", 1] "prod[s1,p2,1] - 80 invest[p2,1] ≤ 0"
    @test_constr model[:eq_invest_prod_ub]["s1", "p2", 4] "prod[s1,p2,4] - 80 invest[p2,4] ≤ 0"

    # eq_invest_prod_lb
    # -------------------------------------------------------------------------
    # p1: no investment cost, constraint should not exist
    @test ("s1", "p1", 1) ∉ keys(model[:eq_invest_prod_lb])

    # p2: production lower bounded by minimum when invested
    @test_constr model[:eq_invest_prod_lb]["s1", "p2", 1] "prod[s1,p2,1] - 5 invest[p2,1] ≥ 0"
    @test_constr model[:eq_invest_prod_lb]["s1", "p2", 4] "prod[s1,p2,4] - 5 invest[p2,4] ≥ 0"

    # net_injection
    # -------------------------------------------------------------------------
    ni = model[:net_injection]

    # p1: bus=b1
    @test_aff_expr ni["s1", "b1", 1] model[:prod]["s1", "p1", 1] 1.0
    @test_aff_expr ni["s1", "b1", 4] model[:prod]["s1", "p1", 4] 1.0

    # p2: bus=b2
    @test_aff_expr ni["s1", "b2", 1] model[:prod]["s1", "p2", 1] 1.0
    @test_aff_expr ni["s1", "b2", 4] model[:prod]["s1", "p2", 4] 1.0
end

function _base_model()
    return UnitCommitment.build_model(
        instance = UnitCommitment.read(fixture("base.json")),
        formulation = UnitCommitment.BaseFormulation,
        optimizer = HiGHS.Optimizer,
        variable_names = true,
    )
end
