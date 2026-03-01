# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using HiGHS, JuMP, UnitCommitment

@testfunction components_flexiramp_build_test begin
    model =
        build_model(
            UnitCommitment.read(
                fixture("case14/flex.json"),
                extensions = [
                    UnitCommitment.ThermalExt(
                        ramping = UnitCommitment.NoRamping(),
                    ),
                    UnitCommitment.WanHob2016.FlexirampExt(),
                ],
            ),
            optimizer = test_optimizer(),
            variable_names = true,
        ).inner

    # Decision variables
    # -------------------------------------------------------------------------
    @test_continuous_var model[:mfg]["s1", "g2", 1] lb = 0
    @test_continuous_var model[:mfg]["s1", "g2", 4] lb = 0
    @test_continuous_var model[:mfg]["s1", "g3", 1] lb = 0
    @test_continuous_var model[:mfg]["s1", "g3", 4] lb = 0
    @test_continuous_var model[:mfg]["s1", "g4", 1] lb = 0
    @test_continuous_var model[:mfg]["s1", "g4", 4] lb = 0
    @test ("s1", "g1", 1) ∉ keys(model[:mfg])

    @test_continuous_var model[:upflexiramp]["s1", "r1", "g2", 1]
    @test_continuous_var model[:upflexiramp]["s1", "r1", "g3", 1]
    @test_continuous_var model[:dwflexiramp]["s1", "r1", "g2", 1]
    @test_continuous_var model[:dwflexiramp]["s1", "r1", "g3", 1]
    @test_continuous_var model[:upflexiramp]["s1", "r2", "g3", 1]
    @test_continuous_var model[:upflexiramp]["s1", "r2", "g4", 1]
    @test ("s1", "r1", 4) ∉ keys(model[:upflexiramp_shortfall])
    @test ("s1", "r2", "g2", 1) ∉ keys(model[:upflexiramp])

    @test_continuous_var model[:upflexiramp_shortfall]["s1", "r1", 1] lb = 0
    @test_continuous_var model[:dwflexiramp_shortfall]["s1", "r1", 1] lb = 0
    @test model[:upflexiramp_shortfall]["s1", "r2", 1] === 0.0
    @test model[:dwflexiramp_shortfall]["s1", "r2", 1] === 0.0

    # Objective coefficients
    # -------------------------------------------------------------------------
    @test_obj_coef model[:upflexiramp_shortfall]["s1", "r1", 1] 5000.0
    @test_obj_coef model[:dwflexiramp_shortfall]["s1", "r1", 1] 5000.0
    # Constraints
    # -------------------------------------------------------------------------
    @test_constr model[:eq_mfg_lb]["s1", "g2", 1] "prod_above[s1,g2,1] - mfg[s1,g2,1] ≤ 0"
    @test_constr model[:eq_mfg_lb]["s1", "g3", 1] "15 is_on[g3,1] + prod_above[s1,g3,1] - mfg[s1,g3,1] ≤ 0"
    @test_constr model[:eq_mfg_lb]["s1", "g4", 1] "33 is_on[g4,1] + prod_above[s1,g4,1] - mfg[s1,g4,1] ≤ 0"

    @test_constr model[:eq_mfg_ub]["s1", "g2", 1] "-140 is_on[g2,1] + mfg[s1,g2,1] ≤ 0"
    @test_constr model[:eq_mfg_ub]["s1", "g3", 1] "-100 is_on[g3,1] + mfg[s1,g3,1] ≤ 0"
    @test_constr model[:eq_mfg_ub]["s1", "g4", 1] "-100 is_on[g4,1] + mfg[s1,g4,1] ≤ 0"

    @test_constr model[:eq_ramp_up]["s1", "g2", 1] "60 is_on[g2,1] + mfg[s1,g2,1] ≤ 238"
    @test_constr model[:eq_ramp_up]["s1", "g3", 1] "30 is_on[g3,1] + mfg[s1,g3,1] ≤ 100"
    @test_constr model[:eq_ramp_up]["s1", "g4", 1] "55 is_on[g4,1] + mfg[s1,g4,1] ≤ 100"
    @test_constr model[:eq_ramp_up]["s1", "g2", 2] "-18 is_on[g2,1] - prod_above[s1,g2,1] + 60 is_on[g2,2] + mfg[s1,g2,2] ≤ 140"
    @test_constr model[:eq_ramp_up]["s1", "g3", 2] "-15 is_on[g3,1] - prod_above[s1,g3,1] + 30 is_on[g3,2] + mfg[s1,g3,2] ≤ 100"
    @test_constr model[:eq_ramp_up]["s1", "g4", 2] "-38 is_on[g4,1] - prod_above[s1,g4,1] + 55 is_on[g4,2] + mfg[s1,g4,2] ≤ 100"

    @test_constr model[:eq_mfg_shutdown]["s1", "g2", 1] "-60 is_on[g2,1] - 80 is_on[g2,2] + mfg[s1,g2,1] ≤ 0"
    @test_constr model[:eq_mfg_shutdown]["s1", "g3", 1] "-70 is_on[g3,1] - 30 is_on[g3,2] + mfg[s1,g3,1] ≤ 0"
    @test_constr model[:eq_mfg_shutdown]["s1", "g4", 1] "-35 is_on[g4,1] - 65 is_on[g4,2] + mfg[s1,g4,1] ≤ 0"
    @test ("s1", "g2", 4) ∉ keys(model[:eq_mfg_shutdown])

    @test_constr model[:eq_ramp_down]["s1", "g2", 1] "-10 is_on[g2,1] - prod_above[s1,g2,1] ≤ -20"
    @test_constr model[:eq_ramp_down]["s1", "g3", 1] "-15 is_on[g3,1] - prod_above[s1,g3,1] ≤ 100"
    @test_constr model[:eq_ramp_down]["s1", "g2", 2] "80 is_on[g2,1] + prod_above[s1,g2,1] - 10 is_on[g2,2] - prod_above[s1,g2,2] ≤ 140"
    @test_constr model[:eq_ramp_down]["s1", "g3", 2] "45 is_on[g3,1] + prod_above[s1,g3,1] - 15 is_on[g3,2] - prod_above[s1,g3,2] ≤ 100"
    @test_constr model[:eq_ramp_down]["s1", "g4", 2] "98 is_on[g4,1] + prod_above[s1,g4,1] - 38 is_on[g4,2] - prod_above[s1,g4,2] ≤ 100"

    @test_constr model[:eq_dwflexi_lb]["s1", "r1", "g2", 1] "-prod_above[s1,g2,1] + dwflexiramp[s1,r1,g2,1] ≤ 0"
    @test_constr model[:eq_dwflexi_ub]["s1", "r1", "g2", 1] "prod_above[s1,g2,1] + 140 is_on[g2,2] - mfg[s1,g2,2] - dwflexiramp[s1,r1,g2,1] ≤ 140"
    @test_constr model[:eq_dwflexi_lb]["s1", "r1", "g3", 1] "-prod_above[s1,g3,1] + 15 is_on[g3,2] + dwflexiramp[s1,r1,g3,1] ≤ 15"
    @test_constr model[:eq_dwflexi_ub]["s1", "r1", "g3", 1] "15 is_on[g3,1] + prod_above[s1,g3,1] + 100 is_on[g3,2] - mfg[s1,g3,2] - dwflexiramp[s1,r1,g3,1] ≤ 100"
    @test_constr model[:eq_dwflexi_lb]["s1", "r2", "g4", 1] "-prod_above[s1,g4,1] + 33 is_on[g4,2] + dwflexiramp[s1,r2,g4,1] ≤ 33"
    @test_constr model[:eq_dwflexi_ub]["s1", "r2", "g4", 1] "33 is_on[g4,1] + prod_above[s1,g4,1] + 100 is_on[g4,2] - mfg[s1,g4,2] - dwflexiramp[s1,r2,g4,1] ≤ 100"
    @test ("s1", "r1", "g2", 4) ∉ keys(model[:eq_dwflexi_lb])

    @test_constr model[:eq_upflexi_lb]["s1", "r1", "g2", 1] "-prod_above[s1,g2,1] - upflexiramp[s1,r1,g2,1] ≤ 0"
    @test_constr model[:eq_upflexi_ub]["s1", "r1", "g2", 1] "prod_above[s1,g2,1] + 140 is_on[g2,2] - mfg[s1,g2,2] + upflexiramp[s1,r1,g2,1] ≤ 140"
    @test_constr model[:eq_upflexi_lb]["s1", "r1", "g3", 1] "-prod_above[s1,g3,1] + 15 is_on[g3,2] - upflexiramp[s1,r1,g3,1] ≤ 15"
    @test_constr model[:eq_upflexi_ub]["s1", "r1", "g3", 1] "15 is_on[g3,1] + prod_above[s1,g3,1] + 100 is_on[g3,2] - mfg[s1,g3,2] + upflexiramp[s1,r1,g3,1] ≤ 100"
    @test_constr model[:eq_upflexi_lb]["s1", "r2", "g4", 1] "-prod_above[s1,g4,1] + 33 is_on[g4,2] - upflexiramp[s1,r2,g4,1] ≤ 33"
    @test_constr model[:eq_upflexi_ub]["s1", "r2", "g4", 1] "33 is_on[g4,1] + prod_above[s1,g4,1] + 100 is_on[g4,2] - mfg[s1,g4,2] + upflexiramp[s1,r2,g4,1] ≤ 100"
    @test ("s1", "r1", "g2", 4) ∉ keys(model[:eq_upflexi_lb])

    @test_constr model[:eq_upflexi_ramp_lb]["s1", "r1", "g2", 1] "80 is_on[g2,1] - 10 is_on[g2,2] - upflexiramp[s1,r1,g2,1] ≤ 140"
    @test_constr model[:eq_upflexi_ramp_ub]["s1", "r1", "g2", 1] "-18 is_on[g2,1] + 60 is_on[g2,2] + upflexiramp[s1,r1,g2,1] ≤ 140"
    @test_constr model[:eq_upflexi_ramp_lb]["s1", "r2", "g4", 1] "65 is_on[g4,1] - 5 is_on[g4,2] - upflexiramp[s1,r2,g4,1] ≤ 100"
    @test_constr model[:eq_upflexi_ramp_ub]["s1", "r2", "g4", 1] "-5 is_on[g4,1] + 55 is_on[g4,2] + upflexiramp[s1,r2,g4,1] ≤ 100"
    @test_constr model[:eq_upflexi_ramp_lb]["s1", "r1", "g3", 1] "30 is_on[g3,1] - upflexiramp[s1,r1,g3,1] ≤ 100"
    @test_constr model[:eq_upflexi_ramp_ub]["s1", "r1", "g3", 1] "30 is_on[g3,2] + upflexiramp[s1,r1,g3,1] ≤ 100"

    @test_constr model[:eq_dwflexi_ramp_lb]["s1", "r1", "g2", 1] "-18 is_on[g2,1] + 60 is_on[g2,2] - dwflexiramp[s1,r1,g2,1] ≤ 140"
    @test_constr model[:eq_dwflexi_ramp_ub]["s1", "r1", "g2", 1] "80 is_on[g2,1] - 10 is_on[g2,2] + dwflexiramp[s1,r1,g2,1] ≤ 140"
    @test_constr model[:eq_dwflexi_ramp_lb]["s1", "r2", "g4", 1] "-5 is_on[g4,1] + 55 is_on[g4,2] - dwflexiramp[s1,r2,g4,1] ≤ 100"
    @test_constr model[:eq_dwflexi_ramp_ub]["s1", "r2", "g4", 1] "65 is_on[g4,1] - 5 is_on[g4,2] + dwflexiramp[s1,r2,g4,1] ≤ 100"

    @test_constr model[:eq_upflexi_power_lb]["s1", "r1", "g2", 1] "-140 is_on[g2,1] - upflexiramp[s1,r1,g2,1] ≤ 0"
    @test_constr model[:eq_upflexi_power_ub]["s1", "r1", "g2", 1] "-140 is_on[g2,2] + upflexiramp[s1,r1,g2,1] ≤ 0"
    @test_constr model[:eq_upflexi_power_lb]["s1", "r1", "g3", 1] "-100 is_on[g3,1] + 15 is_on[g3,2] - upflexiramp[s1,r1,g3,1] ≤ 0"
    @test_constr model[:eq_upflexi_power_ub]["s1", "r1", "g3", 1] "-100 is_on[g3,2] + upflexiramp[s1,r1,g3,1] ≤ 0"
    @test_constr model[:eq_upflexi_power_lb]["s1", "r2", "g4", 1] "-100 is_on[g4,1] + 33 is_on[g4,2] - upflexiramp[s1,r2,g4,1] ≤ 0"
    @test_constr model[:eq_upflexi_power_ub]["s1", "r2", "g4", 1] "-100 is_on[g4,2] + upflexiramp[s1,r2,g4,1] ≤ 0"

    @test_constr model[:eq_dwflexi_power_lb]["s1", "r1", "g2", 1] "-140 is_on[g2,2] - dwflexiramp[s1,r1,g2,1] ≤ 0"
    @test_constr model[:eq_dwflexi_power_ub]["s1", "r1", "g2", 1] "-140 is_on[g2,1] + dwflexiramp[s1,r1,g2,1] ≤ 0"
    @test_constr model[:eq_dwflexi_power_lb]["s1", "r1", "g3", 1] "-100 is_on[g3,2] - dwflexiramp[s1,r1,g3,1] ≤ 0"
    @test_constr model[:eq_dwflexi_power_ub]["s1", "r1", "g3", 1] "-100 is_on[g3,1] + 15 is_on[g3,2] + dwflexiramp[s1,r1,g3,1] ≤ 0"
    @test_constr model[:eq_dwflexi_power_lb]["s1", "r2", "g4", 1] "-100 is_on[g4,2] - dwflexiramp[s1,r2,g4,1] ≤ 0"
    @test_constr model[:eq_dwflexi_power_ub]["s1", "r2", "g4", 1] "-100 is_on[g4,1] + 33 is_on[g4,2] + dwflexiramp[s1,r2,g4,1] ≤ 0"

    @test_constr model[:eq_min_flexiramp_up]["s1", "r1", 1] "upflexiramp_shortfall[s1,r1,1] + upflexiramp[s1,r1,g2,1] + upflexiramp[s1,r1,g3,1] ≥ 20.31"
    @test_constr model[:eq_min_flexiramp_down]["s1", "r1", 1] "dwflexiramp_shortfall[s1,r1,1] + dwflexiramp[s1,r1,g2,1] + dwflexiramp[s1,r1,g3,1] ≥ 20.31"
    @test_constr model[:eq_min_flexiramp_up]["s1", "r2", 1] "upflexiramp[s1,r2,g3,1] + upflexiramp[s1,r2,g4,1] ≥ 15"
    @test_constr model[:eq_min_flexiramp_down]["s1", "r2", 1] "dwflexiramp[s1,r2,g3,1] + dwflexiramp[s1,r2,g4,1] ≥ 15"

    @test_constr model[:eq_dwflexi_lb]["s1", "r2", "g3", 1] "-prod_above[s1,g3,1] + 15 is_on[g3,2] + dwflexiramp[s1,r2,g3,1] ≤ 15"
    @test_constr model[:eq_upflexi_lb]["s1", "r2", "g3", 1] "-prod_above[s1,g3,1] + 15 is_on[g3,2] - upflexiramp[s1,r2,g3,1] ≤ 15"
end
