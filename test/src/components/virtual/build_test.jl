# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using HiGHS, JuMP, UnitCommitment

@testfunction components_virtual_build_test begin
    model =
        build_model(
            UnitCommitment.read(
                fixture("virtual.json"),
                extensions = [UnitCommitment.PhaseAngleTransmissionExt()],
            ),
            optimizer = test_optimizer(),
            variable_names = true,
        ).inner

    # Decision variables
    # -------------------------------------------------------------------------
    # vt_inc1: bus=b1, max_quantity=50.0 (constant)
    @test_continuous_var model[:vt_cleared]["s1", "vt_inc1", 1] lb = 0 ub = 50.0
    @test_continuous_var model[:vt_cleared]["s1", "vt_inc1", 4] lb = 0 ub = 50.0

    # vt_dec1: bus=b3, max_quantity=40.0 (constant)
    @test_continuous_var model[:vt_cleared]["s1", "vt_dec1", 1] lb = 0 ub = 40.0
    @test_continuous_var model[:vt_cleared]["s1", "vt_dec1", 4] lb = 0 ub = 40.0

    # vt_dec2: bus=b3, max_quantity=[30, 40, 20, 35] (time-varying)
    @test_continuous_var model[:vt_cleared]["s1", "vt_dec2", 1] lb = 0 ub = 30.0
    @test_continuous_var model[:vt_cleared]["s1", "vt_dec2", 2] lb = 0 ub = 40.0
    @test_continuous_var model[:vt_cleared]["s1", "vt_dec2", 3] lb = 0 ub = 20.0
    @test_continuous_var model[:vt_cleared]["s1", "vt_dec2", 4] lb = 0 ub = 35.0

    # vt_utc1: source=b1, sink=b3, max_quantity=30.0
    @test_continuous_var model[:vt_cleared]["s1", "vt_utc1", 1] lb = 0 ub = 30.0
    @test_continuous_var model[:vt_cleared]["s1", "vt_utc1", 4] lb = 0 ub = 30.0

    # Objective function
    # -------------------------------------------------------------------------
    # INC: positive coefficient (offer cost), price=30.0, probability=1.0
    @test_obj_coef model[:vt_cleared]["s1", "vt_inc1", 1] 30.0
    @test_obj_coef model[:vt_cleared]["s1", "vt_inc1", 4] 30.0

    # DEC (scalar): negative coefficient (bid benefit), price=60.0
    @test_obj_coef model[:vt_cleared]["s1", "vt_dec1", 1] -60.0
    @test_obj_coef model[:vt_cleared]["s1", "vt_dec1", 4] -60.0

    # DEC (time-varying): price=[50, 55, 45, 52]
    @test_obj_coef model[:vt_cleared]["s1", "vt_dec2", 1] -50.0
    @test_obj_coef model[:vt_cleared]["s1", "vt_dec2", 2] -55.0
    @test_obj_coef model[:vt_cleared]["s1", "vt_dec2", 3] -45.0
    @test_obj_coef model[:vt_cleared]["s1", "vt_dec2", 4] -52.0

    # UTC: negative coefficient (spread bid), price=10.0
    @test_obj_coef model[:vt_cleared]["s1", "vt_utc1", 1] -10.0
    @test_obj_coef model[:vt_cleared]["s1", "vt_utc1", 4] -10.0

    # Net injection
    # -------------------------------------------------------------------------
    ni = model[:net_injection]

    # INC at b1: coefficient +1.0 (injects power)
    @test_aff_expr ni["s1", "b1", 1] model[:vt_cleared]["s1", "vt_inc1", 1] 1.0
    @test_aff_expr ni["s1", "b1", 4] model[:vt_cleared]["s1", "vt_inc1", 4] 1.0

    # DEC at b3: coefficient -1.0 (withdraws power)
    @test_aff_expr ni["s1", "b3", 1] model[:vt_cleared]["s1", "vt_dec1", 1] -1.0
    @test_aff_expr ni["s1", "b3", 4] model[:vt_cleared]["s1", "vt_dec1", 4] -1.0

    # DEC2 at b3: coefficient -1.0 (multiple DECs on same bus)
    @test_aff_expr ni["s1", "b3", 1] model[:vt_cleared]["s1", "vt_dec2", 1] -1.0
    @test_aff_expr ni["s1", "b3", 4] model[:vt_cleared]["s1", "vt_dec2", 4] -1.0

    # UTC source at b1: coefficient +1.0
    @test_aff_expr ni["s1", "b1", 1] model[:vt_cleared]["s1", "vt_utc1", 1] 1.0
    @test_aff_expr ni["s1", "b1", 4] model[:vt_cleared]["s1", "vt_utc1", 4] 1.0

    # UTC sink at b3: coefficient -1.0
    @test_aff_expr ni["s1", "b3", 1] model[:vt_cleared]["s1", "vt_utc1", 1] -1.0
    @test_aff_expr ni["s1", "b3", 4] model[:vt_cleared]["s1", "vt_utc1", 4] -1.0
end
