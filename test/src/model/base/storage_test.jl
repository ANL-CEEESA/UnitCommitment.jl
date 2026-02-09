# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using HiGHS, JuMP, UnitCommitment

@testfunction model_base_storage_test begin
    model = UnitCommitment.build_model(
        instance = UnitCommitment.read(
            fixture("base.json"),
            extensions = [
                UnitCommitment.ThermalExt(
                    pwl_costs = UnitCommitment.BasePwlCosts(),
                ),
                UnitCommitment.StorageExt(),
            ],
        ),
        optimizer = HiGHS.Optimizer,
        variable_names = true,
    )

    # Decision variables
    # -------------------------------------------------------------------------
    # su1: no investment, min_level=10, max_level=100
    @test_continuous_var model[:storage_level]["s1", "su1", 1] lb = 10.0 ub =
        100.0
    @test_continuous_var model[:storage_level]["s1", "su1", 4] lb = 10.0 ub =
        100.0

    # su2: with investment, lower bound overridden to 0
    @test_continuous_var model[:storage_level]["s1", "su2", 1] lb = 0.0 ub =
        200.0
    @test_continuous_var model[:storage_level]["s1", "su2", 4] lb = 0.0 ub =
        200.0

    @test_continuous_var model[:charge_rate]["s1", "su1", 1]
    @test_continuous_var model[:discharge_rate]["s1", "su1", 1]
    @test_binary_var model[:is_charging]["s1", "su1", 1]
    @test_binary_var model[:is_discharging]["s1", "su1", 1]

    @test_binary_var model[:invest_storage]["su2", 1]
    @test_binary_var model[:invest_storage]["su2", 4]
    @test ("su1", 1) ∉ keys(model[:invest_storage])

    # Objective function
    # -------------------------------------------------------------------------
    @test_obj_coef model[:charge_rate]["s1", "su1", 1] 2.0
    @test_obj_coef model[:charge_rate]["s1", "su1", 4] 2.0
    @test_obj_coef model[:discharge_rate]["s1", "su1", 1] 1.5
    @test_obj_coef model[:discharge_rate]["s1", "su1", 4] 1.5
    @test_obj_coef model[:charge_rate]["s1", "su2", 1] 3.0
    @test_obj_coef model[:discharge_rate]["s1", "su2", 1] 2.0

    # su2: invest costs [5000, 6000, 7000, 8000], weight=0.1
    @test_obj_coef model[:invest_storage]["su2", 1] -100.0
    @test_obj_coef model[:invest_storage]["su2", 2] -100.0
    @test_obj_coef model[:invest_storage]["su2", 3] -100.0
    @test_obj_coef model[:invest_storage]["su2", 4] 800.0

    # Constraints
    # -------------------------------------------------------------------------
    # su1: simultaneous=false
    @test_constr model[:eq_simultaneous_charge_and_discharge]["s1", "su1", 1] "is_charging[s1,su1,1] + is_discharging[s1,su1,1] ≤ 1"
    @test_constr model[:eq_simultaneous_charge_and_discharge]["s1", "su1", 4] "is_charging[s1,su1,4] + is_discharging[s1,su1,4] ≤ 1"

    # su2: simultaneous=true
    @test ("s1", "su2", 1) ∉ keys(model[:eq_simultaneous_charge_and_discharge])

    @test_constr model[:eq_min_charge_rate]["s1", "su1", 1] "charge_rate[s1,su1,1] - 5 is_charging[s1,su1,1] ≥ 0"
    @test_constr model[:eq_max_charge_rate]["s1", "su1", 1] "charge_rate[s1,su1,1] - 50 is_charging[s1,su1,1] ≤ 0"
    @test_constr model[:eq_min_discharge_rate]["s1", "su1", 1] "discharge_rate[s1,su1,1] - 3 is_discharging[s1,su1,1] ≥ 0"
    @test_constr model[:eq_max_discharge_rate]["s1", "su1", 1] "discharge_rate[s1,su1,1] - 40 is_discharging[s1,su1,1] ≤ 0"

    # su1, t=1: initial_level=50, loss=0.01, charge_eff=0.9, discharge_eff=0.95
    @test_constr model[:eq_storage_transition]["s1", "su1", 1] "storage_level[s1,su1,1] - 0.9 charge_rate[s1,su1,1] + 1.0526315789473684 discharge_rate[s1,su1,1] = 49.5"
    @test_constr model[:eq_storage_transition]["s1", "su1", 2] "-0.99 storage_level[s1,su1,1] + storage_level[s1,su1,2] - 0.9 charge_rate[s1,su1,2] + 1.0526315789473684 discharge_rate[s1,su1,2] = 0"

    # su1: min_ending=20, max_ending=80
    @test_constr model[:eq_ending_level]["s1", "su1"] "storage_level[s1,su1,4] ∈ [20, 80]"

    # Investment constraints
    @test ("su1", 2) ∉ keys(model[:eq_invest_storage_nondec])
    @test_constr model[:eq_invest_storage_nondec]["su2", 2] "invest_storage[su2,1] - invest_storage[su2,2] ≤ 0"
    @test_constr model[:eq_invest_storage_nondec]["su2", 3] "invest_storage[su2,2] - invest_storage[su2,3] ≤ 0"
    @test_constr model[:eq_invest_storage_nondec]["su2", 4] "invest_storage[su2,3] - invest_storage[su2,4] ≤ 0"

    @test ("s1", "su1", 1) ∉ keys(model[:eq_invest_storage_level_ub])
    @test_constr model[:eq_invest_storage_level_ub]["s1", "su2", 1] "storage_level[s1,su2,1] - 200 invest_storage[su2,1] ≤ 0"
    @test_constr model[:eq_invest_storage_level_ub]["s1", "su2", 4] "storage_level[s1,su2,4] - 200 invest_storage[su2,4] ≤ 0"

    @test ("s1", "su1", 1) ∉ keys(model[:eq_invest_storage_level_lb])
    @test_constr model[:eq_invest_storage_level_lb]["s1", "su2", 1] "storage_level[s1,su2,1] - 20 invest_storage[su2,1] ≥ 0"
    @test_constr model[:eq_invest_storage_level_lb]["s1", "su2", 4] "storage_level[s1,su2,4] - 20 invest_storage[su2,4] ≥ 0"

    # net_injection: su1 on b4, su2 on b5
    ni = model[:net_injection]
    @test_aff_expr ni["s1", "b4", 1] model[:discharge_rate]["s1", "su1", 1] 1.0
    @test_aff_expr ni["s1", "b4", 1] model[:charge_rate]["s1", "su1", 1] -1.0
    @test_aff_expr ni["s1", "b4", 4] model[:discharge_rate]["s1", "su1", 4] 1.0
    @test_aff_expr ni["s1", "b4", 4] model[:charge_rate]["s1", "su1", 4] -1.0
    @test_aff_expr ni["s1", "b5", 1] model[:discharge_rate]["s1", "su2", 1] 1.0
    @test_aff_expr ni["s1", "b5", 1] model[:charge_rate]["s1", "su2", 1] -1.0
end
