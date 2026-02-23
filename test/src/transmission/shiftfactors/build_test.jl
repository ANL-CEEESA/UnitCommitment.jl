# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using HiGHS, JuMP, UnitCommitment

@testfunction transmission_shiftfactors_build_test begin
    model =
        build_model(
            UnitCommitment.read(
                fixture("case5/base.json"),
                extensions = [
                    UnitCommitment.ShiftFactorsTransmissionExt(
                        isf_cutoff = 0.0,
                        lodf_cutoff = 0.0,
                    ),
                ],
            ),
            optimizer = test_optimizer(),
            variable_names = true,
        ).inner

    # Decision variables
    # -------------------------------------------------------------------------
    @test_continuous_var model[:overflow]["s1", "l1", 1] lb = 0
    @test_continuous_var model[:overflow]["s1", "l2", 1] lb = 0
    @test_continuous_var model[:overflow]["s1", "l3", 1] lb = 0
    @test_continuous_var model[:overflow]["s1", "l4", 1] lb = 0
    @test_continuous_var model[:overflow]["s1", "l5", 1] lb = 0
    @test_continuous_var model[:overflow]["s1", "l6", 1] lb = 0
    @test_continuous_var model[:overflow]["s1", "l7", 1] lb = 0

    @test_continuous_var model[:flow]["s1", "l1", 1]
    @test_continuous_var model[:flow]["s1", "l2", 1]
    @test_continuous_var model[:flow]["s1", "l3", 1]
    @test_continuous_var model[:flow]["s1", "l4", 1]
    @test_continuous_var model[:flow]["s1", "l5", 1]
    @test_continuous_var model[:flow]["s1", "l6", 1]
    @test_continuous_var model[:flow]["s1", "l7", 1]

    @test_continuous_var model[:flow_cont]["s1", "c1", "l1", 1]
    @test_continuous_var model[:flow_cont]["s1", "c1", "l2", 1]
    @test_continuous_var model[:flow_cont]["s1", "c1", "l3", 1]
    @test_continuous_var model[:flow_cont]["s1", "c1", "l4", 1]
    @test_continuous_var model[:flow_cont]["s1", "c1", "l5", 1]
    @test_continuous_var model[:flow_cont]["s1", "c1", "l6", 1]
    @test_continuous_var model[:flow_cont]["s1", "c1", "l7", 1]

    # Objective function
    # -------------------------------------------------------------------------
    @test_obj_coef model[:overflow]["s1", "l1", 1] 1000.0
    @test_obj_coef model[:overflow]["s1", "l2", 1] 2000.0
    @test_obj_coef model[:overflow]["s1", "l3", 1] 1500.0
    @test_obj_coef model[:overflow]["s1", "l4", 1] 1200.0
    @test_obj_coef model[:overflow]["s1", "l5", 1] 1800.0
    @test_obj_coef model[:overflow]["s1", "l6", 1] 2200.0
    @test_obj_coef model[:overflow]["s1", "l7", 1] 700.0

    # eq_flow_def
    # -------------------------------------------------------------------------
    @test_constr model[:eq_flow_def]["s1", "l1", 1] "0.459 ni[s1,b2,1] + 0.207 ni[s1,b3,1] + 0.253 ni[s1,b4,1] + 0.238 ni[s1,b5,1] + flow[s1,l1,1] = 0"
    @test_constr model[:eq_flow_def]["s1", "l2", 1] "0.415 ni[s1,b2,1] + 0.687 ni[s1,b3,1] + 0.421 ni[s1,b4,1] + 0.508 ni[s1,b5,1] + flow[s1,l2,1] = 0"
    @test_constr model[:eq_flow_def]["s1", "l3", 1] "-0.377 ni[s1,b2,1] + 0.205 ni[s1,b3,1] - 0.064 ni[s1,b4,1] + 0.023 ni[s1,b5,1] + flow[s1,l3,1] = 0"
    @test_constr model[:eq_flow_def]["s1", "l4", 1] "-0.164 ni[s1,b2,1] + 0.003 ni[s1,b3,1] + 0.318 ni[s1,b4,1] + 0.216 ni[s1,b5,1] + flow[s1,l4,1] = 0"
    @test_constr model[:eq_flow_def]["s1", "l5", 1] "0.037 ni[s1,b2,1] - 0.108 ni[s1,b3,1] + 0.357 ni[s1,b4,1] + 0.53 ni[s1,b5,1] + flow[s1,l5,1] = 0"
    @test_constr model[:eq_flow_def]["s1", "l6", 1] "-0.037 ni[s1,b2,1] + 0.108 ni[s1,b3,1] - 0.357 ni[s1,b4,1] + 0.47 ni[s1,b5,1] + flow[s1,l6,1] = 0"
    @test_constr model[:eq_flow_def]["s1", "l7", 1] "0.127 ni[s1,b2,1] + 0.105 ni[s1,b3,1] + 0.325 ni[s1,b4,1] + 0.254 ni[s1,b5,1] + flow[s1,l7,1] = 0"

    # eq_flow_limit_ub and eq_flow_limit_lb (base case, normal_flow_limit)
    # -------------------------------------------------------------------------
    @test_constr model[:eq_flow_limit_ub]["s1", "l1", 1] "-overflow[s1,l1,1] + flow[s1,l1,1] ≤ 100"
    @test_constr model[:eq_flow_limit_lb]["s1", "l1", 1] "overflow[s1,l1,1] + flow[s1,l1,1] ≥ -100"

    @test_constr model[:eq_flow_limit_ub]["s1", "l2", 1] "-overflow[s1,l2,1] + flow[s1,l2,1] ≤ 150"
    @test_constr model[:eq_flow_limit_lb]["s1", "l2", 1] "overflow[s1,l2,1] + flow[s1,l2,1] ≥ -150"

    @test_constr model[:eq_flow_limit_ub]["s1", "l3", 1] "-overflow[s1,l3,1] + flow[s1,l3,1] ≤ 80"
    @test_constr model[:eq_flow_limit_lb]["s1", "l3", 1] "overflow[s1,l3,1] + flow[s1,l3,1] ≥ -80"

    @test_constr model[:eq_flow_limit_ub]["s1", "l4", 1] "-overflow[s1,l4,1] + flow[s1,l4,1] ≤ 120"
    @test_constr model[:eq_flow_limit_lb]["s1", "l4", 1] "overflow[s1,l4,1] + flow[s1,l4,1] ≥ -120"

    @test_constr model[:eq_flow_limit_ub]["s1", "l5", 1] "-overflow[s1,l5,1] + flow[s1,l5,1] ≤ 90"
    @test_constr model[:eq_flow_limit_lb]["s1", "l5", 1] "overflow[s1,l5,1] + flow[s1,l5,1] ≥ -90"

    @test_constr model[:eq_flow_limit_ub]["s1", "l6", 1] "-overflow[s1,l6,1] + flow[s1,l6,1] ≤ 110"
    @test_constr model[:eq_flow_limit_lb]["s1", "l6", 1] "overflow[s1,l6,1] + flow[s1,l6,1] ≥ -110"

    @test_constr model[:eq_flow_limit_ub]["s1", "l7", 1] "-overflow[s1,l7,1] + flow[s1,l7,1] ≤ 70"
    @test_constr model[:eq_flow_limit_lb]["s1", "l7", 1] "overflow[s1,l7,1] + flow[s1,l7,1] ≥ -70"

    # eq_flow_cont_def: contingency c1 (outage of l3)
    # -------------------------------------------------------------------------
    @test_constr model[:eq_flow_cont_def]["s1", "c1", "l1", 1] "0.685 ni[s1,b2,1] + 0.084 ni[s1,b3,1] + 0.292 ni[s1,b4,1] + 0.225 ni[s1,b5,1] + flow_cont[s1,c1,l1,1] = 0"
    @test_constr model[:eq_flow_cont_def]["s1", "c1", "l2", 1] "0.169 ni[s1,b2,1] + 0.821 ni[s1,b3,1] + 0.379 ni[s1,b4,1] + 0.522 ni[s1,b5,1] + flow_cont[s1,c1,l2,1] = 0"
    @test_constr model[:eq_flow_cont_def]["s1", "c1", "l3", 1] "flow_cont[s1,c1,l3,1] = 0"
    @test_constr model[:eq_flow_cont_def]["s1", "c1", "l4", 1] "-0.315 ni[s1,b2,1] + 0.084 ni[s1,b3,1] + 0.292 ni[s1,b4,1] + 0.225 ni[s1,b5,1] + flow_cont[s1,c1,l4,1] = 0"
    @test_constr model[:eq_flow_cont_def]["s1", "c1", "l5", 1] "0.169 ni[s1,b2,1] - 0.179 ni[s1,b3,1] + 0.379 ni[s1,b4,1] + 0.522 ni[s1,b5,1] + flow_cont[s1,c1,l5,1] = 0"
    @test_constr model[:eq_flow_cont_def]["s1", "c1", "l6", 1] "-0.169 ni[s1,b2,1] + 0.179 ni[s1,b3,1] - 0.379 ni[s1,b4,1] + 0.478 ni[s1,b5,1] + flow_cont[s1,c1,l6,1] = 0"
    @test_constr model[:eq_flow_cont_def]["s1", "c1", "l7", 1] "0.146 ni[s1,b2,1] + 0.095 ni[s1,b3,1] + 0.329 ni[s1,b4,1] + 0.253 ni[s1,b5,1] + flow_cont[s1,c1,l7,1] = 0"

    # eq_flow_cont_limit_ub and eq_flow_cont_limit_lb (emergency_flow_limit)
    # -------------------------------------------------------------------------
    @test_constr model[:eq_flow_cont_limit_ub]["s1", "c1", "l1", 1] "-overflow[s1,l1,1] + flow_cont[s1,c1,l1,1] ≤ 200"
    @test_constr model[:eq_flow_cont_limit_lb]["s1", "c1", "l1", 1] "overflow[s1,l1,1] + flow_cont[s1,c1,l1,1] ≥ -200"

    @test_constr model[:eq_flow_cont_limit_ub]["s1", "c1", "l2", 1] "-overflow[s1,l2,1] + flow_cont[s1,c1,l2,1] ≤ 300"
    @test_constr model[:eq_flow_cont_limit_lb]["s1", "c1", "l2", 1] "overflow[s1,l2,1] + flow_cont[s1,c1,l2,1] ≥ -300"

    @test_constr model[:eq_flow_cont_limit_ub]["s1", "c1", "l3", 1] "-overflow[s1,l3,1] + flow_cont[s1,c1,l3,1] ≤ 160"
    @test_constr model[:eq_flow_cont_limit_lb]["s1", "c1", "l3", 1] "overflow[s1,l3,1] + flow_cont[s1,c1,l3,1] ≥ -160"

    @test_constr model[:eq_flow_cont_limit_ub]["s1", "c1", "l4", 1] "-overflow[s1,l4,1] + flow_cont[s1,c1,l4,1] ≤ 240"
    @test_constr model[:eq_flow_cont_limit_lb]["s1", "c1", "l4", 1] "overflow[s1,l4,1] + flow_cont[s1,c1,l4,1] ≥ -240"

    @test_constr model[:eq_flow_cont_limit_ub]["s1", "c1", "l5", 1] "-overflow[s1,l5,1] + flow_cont[s1,c1,l5,1] ≤ 180"
    @test_constr model[:eq_flow_cont_limit_lb]["s1", "c1", "l5", 1] "overflow[s1,l5,1] + flow_cont[s1,c1,l5,1] ≥ -180"

    @test_constr model[:eq_flow_cont_limit_ub]["s1", "c1", "l6", 1] "-overflow[s1,l6,1] + flow_cont[s1,c1,l6,1] ≤ 220"
    @test_constr model[:eq_flow_cont_limit_lb]["s1", "c1", "l6", 1] "overflow[s1,l6,1] + flow_cont[s1,c1,l6,1] ≥ -220"

    @test_constr model[:eq_flow_cont_limit_ub]["s1", "c1", "l7", 1] "-overflow[s1,l7,1] + flow_cont[s1,c1,l7,1] ≤ 140"
    @test_constr model[:eq_flow_cont_limit_lb]["s1", "c1", "l7", 1] "overflow[s1,l7,1] + flow_cont[s1,c1,l7,1] ≥ -140"
end

@testfunction transmission_shiftfactors_build_lazy_test begin
    model =
        build_model(
            UnitCommitment.read(
                fixture("case5/base.json"),
                extensions = [
                    UnitCommitment.ShiftFactorsTransmissionExt(
                        isf_cutoff = 0.0,
                        lodf_cutoff = 0.0,
                        lazy = true,
                    ),
                ],
            ),
            optimizer = test_optimizer(),
            variable_names = true,
        ).inner

    # Decision variables
    # -------------------------------------------------------------------------

    # overflow: still created in lazy mode
    @test_continuous_var model[:overflow]["s1", "l1", 1] lb = 0
    @test_continuous_var model[:overflow]["s1", "l2", 1] lb = 0
    @test_continuous_var model[:overflow]["s1", "l3", 1] lb = 0
    @test_continuous_var model[:overflow]["s1", "l4", 1] lb = 0
    @test_continuous_var model[:overflow]["s1", "l5", 1] lb = 0
    @test_continuous_var model[:overflow]["s1", "l6", 1] lb = 0
    @test_continuous_var model[:overflow]["s1", "l7", 1] lb = 0

    # flow and flow_cont: NOT created in lazy mode
    @test !haskey(model, :flow)
    @test !haskey(model, :flow_cont)

    # Objective function
    # -------------------------------------------------------------------------
    @test_obj_coef model[:overflow]["s1", "l1", 1] 1000.0
    @test_obj_coef model[:overflow]["s1", "l2", 1] 2000.0
    @test_obj_coef model[:overflow]["s1", "l3", 1] 1500.0
    @test_obj_coef model[:overflow]["s1", "l4", 1] 1200.0
    @test_obj_coef model[:overflow]["s1", "l5", 1] 1800.0
    @test_obj_coef model[:overflow]["s1", "l6", 1] 2200.0
    @test_obj_coef model[:overflow]["s1", "l7", 1] 700.0

    # No flow constraints in lazy mode
    # -------------------------------------------------------------------------
    @test !haskey(model, :eq_flow_def)
    @test !haskey(model, :eq_flow_limit_ub)
    @test !haskey(model, :eq_flow_limit_lb)
    @test !haskey(model, :eq_flow_cont_def)
    @test !haskey(model, :eq_flow_cont_limit_ub)
    @test !haskey(model, :eq_flow_cont_limit_lb)
end
