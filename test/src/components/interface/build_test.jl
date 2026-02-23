# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using HiGHS, JuMP, UnitCommitment

@testfunction components_interface_build_sf_test begin
    model =
        build_model(
            UnitCommitment.read(fixture("case14/interface.json")),
            optimizer = test_optimizer(),
            variable_names = true,
        ).inner

    # Decision variables
    # -------------------------------------------------------------------------
    # ifc1: lines l1 (w=1) and l2 (w=1)
    @test_continuous_var model[:interface_flow]["s1", "ifc1", 1]
    @test_continuous_var model[:interface_overflow]["s1", "ifc1", 1] lb = 0.0

    # ifc2: lines l3 (w=1) and l7 (w=-1), time-varying limits
    @test_continuous_var model[:interface_flow]["s1", "ifc2", 1]
    @test_continuous_var model[:interface_overflow]["s1", "ifc2", 1] lb = 0.0

    # Objective function
    # -------------------------------------------------------------------------
    # penalty * probability
    @test_obj_coef model[:interface_overflow]["s1", "ifc1", 1] 5000.0
    @test_obj_coef model[:interface_overflow]["s1", "ifc2", 1] 5000.0

    # eq_interface_flow_def
    # -------------------------------------------------------------------------
    # ifc1: interface_isf coefficients are all 1.0 (l1+l2 carry all flow from reference bus b1)
    @test_constr model[:eq_interface_flow_def]["s1", "ifc1", 1] "ni[s1,b2,1] + ni[s1,b3,1] + ni[s1,b4,1] + ni[s1,b5,1] + ni[s1,b6,1] + ni[s1,b7,1] + ni[s1,b8,1] + ni[s1,b9,1] + ni[s1,b10,1] + ni[s1,b11,1] + ni[s1,b12,1] + ni[s1,b13,1] + ni[s1,b14,1] + interface_flow[s1,ifc1,1] = 0"

    # ifc2: weighted combination of ISFs for l3 (w=1) and l7 (w=-1)
    @test_constr model[:eq_interface_flow_def]["s1", "ifc2", 1] "0.053 ni[s1,b2,1] + 0.839 ni[s1,b3,1] + 0.655 ni[s1,b4,1] - 0.199 ni[s1,b5,1] + 0.092 ni[s1,b6,1] + 0.502 ni[s1,b7,1] + 0.502 ni[s1,b8,1] + 0.421 ni[s1,b9,1] + 0.363 ni[s1,b10,1] + 0.229 ni[s1,b11,1] + 0.121 ni[s1,b12,1] + 0.138 ni[s1,b13,1] + 0.297 ni[s1,b14,1] + interface_flow[s1,ifc2,1] = 0" digits =
        3

    # eq_interface_flow_ub and eq_interface_flow_lb
    # -------------------------------------------------------------------------
    # ifc1: symmetric bounds ±120
    @test_constr model[:eq_interface_flow_ub]["s1", "ifc1", 1] "interface_flow[s1,ifc1,1] - interface_overflow[s1,ifc1,1] ≤ 120"
    @test_constr model[:eq_interface_flow_lb]["s1", "ifc1", 1] "interface_flow[s1,ifc1,1] + interface_overflow[s1,ifc1,1] ≥ -120"

    # ifc2: time-varying upper limit (t=1 has ub=50)
    @test_constr model[:eq_interface_flow_ub]["s1", "ifc2", 1] "interface_flow[s1,ifc2,1] - interface_overflow[s1,ifc2,1] ≤ 50"
end

@testfunction components_interface_build_pa_test begin
    model =
        build_model(
            UnitCommitment.read(
                fixture("case14/interface.json"),
                extensions = [UnitCommitment.PhaseAngleTransmissionExt()],
            ),
            optimizer = test_optimizer(),
            variable_names = true,
        ).inner

    # Decision variables
    # -------------------------------------------------------------------------
    @test_continuous_var model[:interface_flow]["s1", "ifc1", 1]
    @test_continuous_var model[:interface_overflow]["s1", "ifc1", 1] lb = 0.0

    # eq_interface_flow_def
    # -------------------------------------------------------------------------
    # ifc1: flow definition using phase angle flow variables (w=1 for l1 and l2)
    @test_constr model[:eq_interface_flow_def]["s1", "ifc1", 1] "-flow[s1,l1,1] - flow[s1,l2,1] + interface_flow[s1,ifc1,1] = 0"

    # eq_interface_flow_ub and eq_interface_flow_lb
    # -------------------------------------------------------------------------
    @test_constr model[:eq_interface_flow_ub]["s1", "ifc1", 1] "interface_flow[s1,ifc1,1] - interface_overflow[s1,ifc1,1] ≤ 120"
    @test_constr model[:eq_interface_flow_lb]["s1", "ifc1", 1] "interface_flow[s1,ifc1,1] + interface_overflow[s1,ifc1,1] ≥ -120"
end

@testfunction components_interface_build_empty_test begin
    model =
        build_model(
            UnitCommitment.read(fixture("case14/base.json")),
            optimizer = test_optimizer(),
            variable_names = true,
        ).inner

    @test !haskey(object_dictionary(model), :interface_flow)
end
