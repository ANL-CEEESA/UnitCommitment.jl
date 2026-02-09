# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using HiGHS, JuMP, UnitCommitment

@testfunction model_base_bus_test begin
    model = UnitCommitment.build_model(
        instance = UnitCommitment.read(
            fixture("base.json"),
            extensions = [UnitCommitment.PriceSensitiveLoads()],
        ),
        formulation = UnitCommitment.BaseFormulation,
        optimizer = HiGHS.Optimizer,
        variable_names = true,
    )

    # Decision variables
    # -------------------------------------------------------------------------
    # curtail: b1 (zero load)
    @test_continuous_var model[:curtail]["s1", "b1", 1] lb = 0 ub = 0
    @test_continuous_var model[:curtail]["s1", "b1", 4] lb = 0 ub = 0

    # curtail: b2 (positive load [26.01527, 24.46212, 23.29725, 22.90897])
    @test_continuous_var model[:curtail]["s1", "b2", 1] lb = 0 ub = 26.01527
    @test_continuous_var model[:curtail]["s1", "b2", 4] lb = 0 ub = 22.90897

    # curtail: b15 (mixed load [-5, 10, 0, -3], bounds = [min(0, load), max(0, load)])
    @test_continuous_var model[:curtail]["s1", "b15", 1] lb = -5.0 ub = 0
    @test_continuous_var model[:curtail]["s1", "b15", 2] lb = 0 ub = 10.0
    @test_continuous_var model[:curtail]["s1", "b15", 3] lb = 0 ub = 0
    @test_continuous_var model[:curtail]["s1", "b15", 4] lb = -3.0 ub = 0

    # ni
    @test_continuous_var model[:ni]["s1", "b1", 1]
    @test_continuous_var model[:ni]["s1", "b2", 1]
    @test_continuous_var model[:ni]["s1", "b15", 1]

    # Objective function
    # -------------------------------------------------------------------------
    # power_balance_penalty=1000, probability=1.0
    # For negative loads, coefficient is multiplied by -1
    @test_obj_coef model[:curtail]["s1", "b1", 1] 1000.0
    @test_obj_coef model[:curtail]["s1", "b2", 1] 1000.0
    @test_obj_coef model[:curtail]["s1", "b15", 1] -1000.0
    @test_obj_coef model[:curtail]["s1", "b15", 2] 1000.0

    # eq_net_injection
    # -------------------------------------------------------------------------
    @test_constr model[:eq_net_injection]["s1", "b7", 1] "-loads[s1,ps3,1] + curtail[s1,b7,1] - ni[s1,b7,1] = 0"
    @test_constr model[:eq_net_injection]["s1", "b7", 2] "-loads[s1,ps3,2] + curtail[s1,b7,2] - ni[s1,b7,2] = 0"
    @test_constr model[:eq_net_injection]["s1", "b15", 1] "curtail[s1,b15,1] - ni[s1,b15,1] = -5"
    @test_constr model[:eq_net_injection]["s1", "b15", 2] "curtail[s1,b15,2] - ni[s1,b15,2] = 10"

    # eq_power_balance
    # -------------------------------------------------------------------------
    @test_constr model[:eq_power_balance]["s1", 1] "ni[s1,b1,1] + ni[s1,b2,1] + ni[s1,b3,1] + ni[s1,b4,1] + ni[s1,b5,1] + ni[s1,b6,1] + ni[s1,b7,1] + ni[s1,b8,1] + ni[s1,b9,1] + ni[s1,b10,1] + ni[s1,b11,1] + ni[s1,b12,1] + ni[s1,b13,1] + ni[s1,b14,1] + ni[s1,b15,1] = 0"
    @test_constr model[:eq_power_balance]["s1", 2] "ni[s1,b1,2] + ni[s1,b2,2] + ni[s1,b3,2] + ni[s1,b4,2] + ni[s1,b5,2] + ni[s1,b6,2] + ni[s1,b7,2] + ni[s1,b8,2] + ni[s1,b9,2] + ni[s1,b10,2] + ni[s1,b11,2] + ni[s1,b12,2] + ni[s1,b13,2] + ni[s1,b14,2] + ni[s1,b15,2] = 0"
end
