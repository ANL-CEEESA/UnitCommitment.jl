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
    @test_constr model[:eq_flow_def]["s1", "l1", 1] "0.45869740803289527 ni[s1,b2,1] + 0.20728394155224322 ni[s1,b3,1] + 0.2534694177252368 ni[s1,b4,1] + 0.2384903443718335 ni[s1,b5,1] + flow[s1,l1,1] = 0"
    @test_constr model[:eq_flow_def]["s1", "l2", 1] "0.41456788310448645 ni[s1,b2,1] + 0.6874219839929512 ni[s1,b3,1] + 0.4211762978192233 ni[s1,b4,1] + 0.5075262500917838 ni[s1,b5,1] + flow[s1,l2,1] = 0"
    @test_constr model[:eq_flow_def]["s1", "l3", 1] "-0.377120199720978 ni[s1,b2,1] + 0.20464057566634852 ni[s1,b3,1] - 0.06432190322343778 ni[s1,b4,1] + 0.02290917101108758 ni[s1,b5,1] + flow[s1,l3,1] = 0"
    @test_constr model[:eq_flow_def]["s1", "l4", 1] "-0.16418239224612674 ni[s1,b2,1] + 0.0026433658858946996 ni[s1,b3,1] + 0.3177913209486747 ni[s1,b4,1] + 0.21558117336074606 ni[s1,b5,1] + flow[s1,l4,1] = 0"
    @test_constr model[:eq_flow_def]["s1", "l5", 1] "0.03744768338350837 ni[s1,b2,1] - 0.10793744034070046 ni[s1,b3,1] + 0.3568543945957853 ni[s1,b4,1] + 0.530435421102871 ni[s1,b5,1] + flow[s1,l5,1] = 0"
    @test_constr model[:eq_flow_def]["s1", "l6", 1] "-0.037447683383508235 ni[s1,b2,1] + 0.10793744034070052 ni[s1,b3,1] - 0.35685439459578516 ni[s1,b4,1] + 0.4695645788971292 ni[s1,b5,1] + flow[s1,l6,1] = 0"
    @test_constr model[:eq_flow_def]["s1", "l7", 1] "0.1267347088626184 ni[s1,b2,1] + 0.1052940744548058 ni[s1,b3,1] + 0.3253542844555401 ni[s1,b4,1] + 0.25398340553638304 ni[s1,b5,1] + flow[s1,l7,1] = 0"

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
    @test_constr model[:eq_flow_cont_def]["s1", "c1", "l1", 1] "0.6853932584269663 ni[s1,b2,1] + 0.08426966292134831 ni[s1,b3,1] + 0.2921348314606741 ni[s1,b4,1] + 0.22471910112359547 ni[s1,b5,1] + flow_cont[s1,c1,l1,1] = 0"
    @test_constr model[:eq_flow_cont_def]["s1", "c1", "l2", 1] "0.16853932584269665 ni[s1,b2,1] + 0.820926966292135 ni[s1,b3,1] + 0.37921348314606756 ni[s1,b4,1] + 0.5224719101123598 ni[s1,b5,1] + flow_cont[s1,c1,l2,1] = 0"
    @test_constr model[:eq_flow_cont_def]["s1", "c1", "l3", 1] "flow_cont[s1,c1,l3,1] = 0"
    @test_constr model[:eq_flow_cont_def]["s1", "c1", "l4", 1] "-0.3146067415730337 ni[s1,b2,1] + 0.08426966292134831 ni[s1,b3,1] + 0.2921348314606742 ni[s1,b4,1] + 0.2247191011235956 ni[s1,b5,1] + flow_cont[s1,c1,l4,1] = 0"
    @test_constr model[:eq_flow_cont_def]["s1", "c1", "l5", 1] "0.16853932584269665 ni[s1,b2,1] - 0.17907303370786515 ni[s1,b3,1] + 0.37921348314606734 ni[s1,b4,1] + 0.5224719101123595 ni[s1,b5,1] + flow_cont[s1,c1,l5,1] = 0"
    @test_constr model[:eq_flow_cont_def]["s1", "c1", "l6", 1] "-0.16853932584269646 ni[s1,b2,1] + 0.17907303370786518 ni[s1,b3,1] - 0.37921348314606723 ni[s1,b4,1] + 0.47752808988764067 ni[s1,b5,1] + flow_cont[s1,c1,l6,1] = 0"
    @test_constr model[:eq_flow_cont_def]["s1", "c1", "l7", 1] "0.14606741573033705 ni[s1,b2,1] + 0.09480337078651688 ni[s1,b3,1] + 0.32865168539325845 ni[s1,b4,1] + 0.252808988764045 ni[s1,b5,1] + flow_cont[s1,c1,l7,1] = 0"

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
