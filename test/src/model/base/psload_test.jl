# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using HiGHS, JuMP, UnitCommitment

@testfunction model_base_psload_test begin
    model = UnitCommitment.build_model(
        instance = UnitCommitment.read(
            fixture("base.json"),
            extensions = [
                UnitCommitment.ThermalExt(
                    pwl_costs = UnitCommitment.BasePwlCosts(),
                ),
                UnitCommitment.PriceSensitiveLoadsExt(),
            ],
        ),
        optimizer = HiGHS.Optimizer,
        variable_names = true,
    )

    # Decision variables
    # -------------------------------------------------------------------------
    # ps1: bus=b3, demand=50.0 (constant), revenue=100.0
    @test_continuous_var model[:loads]["s1", "ps1", 1] lb = 0 ub = 50.0
    @test_continuous_var model[:loads]["s1", "ps1", 4] lb = 0 ub = 50.0

    # ps2: bus=b3, demand=[30, 40, 20, 35] (time-varying), revenue=[80, 90, 70, 85]
    @test_continuous_var model[:loads]["s1", "ps2", 1] lb = 0 ub = 30.0
    @test_continuous_var model[:loads]["s1", "ps2", 2] lb = 0 ub = 40.0
    @test_continuous_var model[:loads]["s1", "ps2", 3] lb = 0 ub = 20.0
    @test_continuous_var model[:loads]["s1", "ps2", 4] lb = 0 ub = 35.0

    # ps3: bus=b7, demand=0 (zero demand)
    @test_continuous_var model[:loads]["s1", "ps3", 1] lb = 0 ub = 0
    @test_continuous_var model[:loads]["s1", "ps3", 4] lb = 0 ub = 0

    # Objective function
    # -------------------------------------------------------------------------
    # ps1: revenue=100.0, probability=1.0, coefficient = -100.0
    @test_obj_coef model[:loads]["s1", "ps1", 1] -100.0
    @test_obj_coef model[:loads]["s1", "ps1", 4] -100.0

    # ps2: time-varying revenue, probability=1.0
    @test_obj_coef model[:loads]["s1", "ps2", 1] -80.0
    @test_obj_coef model[:loads]["s1", "ps2", 2] -90.0
    @test_obj_coef model[:loads]["s1", "ps2", 3] -70.0
    @test_obj_coef model[:loads]["s1", "ps2", 4] -85.0

    # ps3: revenue=0.0, coefficient = 0.0
    @test_obj_coef model[:loads]["s1", "ps3", 1] 0.0
    @test_obj_coef model[:loads]["s1", "ps3", 4] 0.0

    # net_injection
    # -------------------------------------------------------------------------
    ni = model[:net_injection]

    # ps1: bus=b3, coefficient=-1.0
    @test_aff_expr ni["s1", "b3", 1] model[:loads]["s1", "ps1", 1] -1.0
    @test_aff_expr ni["s1", "b3", 4] model[:loads]["s1", "ps1", 4] -1.0

    # ps2: bus=b3, coefficient=-1.0 (multiple PS loads on same bus)
    @test_aff_expr ni["s1", "b3", 1] model[:loads]["s1", "ps2", 1] -1.0
    @test_aff_expr ni["s1", "b3", 4] model[:loads]["s1", "ps2", 4] -1.0

    # ps3: bus=b7, coefficient=-1.0 (different bus)
    @test_aff_expr ni["s1", "b7", 1] model[:loads]["s1", "ps3", 1] -1.0
    @test_aff_expr ni["s1", "b7", 4] model[:loads]["s1", "ps3", 4] -1.0
end
