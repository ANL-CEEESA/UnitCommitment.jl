# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using HiGHS, JuMP, UnitCommitment

@testfunction transmission_ac_rect_build_test begin
    model =
        build_model(
            UnitCommitment.read(
                fixture("ac_3bus.json"),
                extensions = [UnitCommitment.ACTransmissionExt()],
            ),
            optimizer = test_optimizer(),
            variable_names = true,
        ).inner

    # Voltage variables (ACR: vr, vi)
    # -------------------------------------------------------------------------
    # All buses have vmin=0.95, vmax=1.05
    @test_continuous_var model[:vr]["s1", "b1", 1] lb = -1.05 ub = 1.05
    @test_continuous_var model[:vr]["s1", "b2", 1] lb = -1.05 ub = 1.05
    @test_continuous_var model[:vr]["s1", "b3", 1] lb = -1.05 ub = 1.05
    @test_continuous_var model[:vi]["s1", "b1", 1] lb = -1.05 ub = 1.05
    @test_continuous_var model[:vi]["s1", "b2", 1] lb = -1.05 ub = 1.05
    @test_continuous_var model[:vi]["s1", "b3", 1] lb = -1.05 ub = 1.05

    # Flow variables (pf, pt, qf, qt, overflow)
    # -------------------------------------------------------------------------
    @test_continuous_var model[:pf]["s1", "l1", 1]
    @test_continuous_var model[:pt]["s1", "l1", 1]
    @test_continuous_var model[:qf]["s1", "l1", 1]
    @test_continuous_var model[:qt]["s1", "l1", 1]
    @test_continuous_var model[:pf]["s1", "l2", 1]
    @test_continuous_var model[:pt]["s1", "l2", 1]
    @test_continuous_var model[:qf]["s1", "l2", 1]
    @test_continuous_var model[:qt]["s1", "l2", 1]
    @test_continuous_var model[:pf]["s1", "l3", 1]
    @test_continuous_var model[:pt]["s1", "l3", 1]
    @test_continuous_var model[:qf]["s1", "l3", 1]
    @test_continuous_var model[:qt]["s1", "l3", 1]
    @test_continuous_var model[:overflow]["s1", "l1", 1] lb = 0
    @test_continuous_var model[:overflow]["s1", "l2", 1] lb = 0
    @test_continuous_var model[:overflow]["s1", "l3", 1] lb = 0

    # Voltage magnitude constraints (ACR only)
    # -------------------------------------------------------------------------
    @test_constr model[:eq_voltage_mag_lb]["s1", "b1", 1] "-vr[s1,b1,1]² - vi[s1,b1,1]² ≤ -0.902"
    @test_constr model[:eq_voltage_mag_lb]["s1", "b2", 1] "-vr[s1,b2,1]² - vi[s1,b2,1]² ≤ -0.902"
    @test_constr model[:eq_voltage_mag_lb]["s1", "b3", 1] "-vr[s1,b3,1]² - vi[s1,b3,1]² ≤ -0.902"
    @test_constr model[:eq_voltage_mag_ub]["s1", "b1", 1] "vr[s1,b1,1]² + vi[s1,b1,1]² ≤ 1.102"
    @test_constr model[:eq_voltage_mag_ub]["s1", "b2", 1] "vr[s1,b2,1]² + vi[s1,b2,1]² ≤ 1.102"
    @test_constr model[:eq_voltage_mag_ub]["s1", "b3", 1] "vr[s1,b3,1]² + vi[s1,b3,1]² ≤ 1.102"

    # Voltage reference constraint (slack bus b1 only)
    # -------------------------------------------------------------------------
    @test_constr model[:eq_voltage_ref]["s1", "b1", 1] "vi[s1,b1,1] = 0"
    @test ("s1", "b2", 1) ∉ keys(model[:eq_voltage_ref])
    @test ("s1", "b3", 1) ∉ keys(model[:eq_voltage_ref])

    # Ohm's law constraints
    # -------------------------------------------------------------------------
    # l1: b1 → b2, r=0.01, x=0.05, bs=0.04, tap=1.0, shift=0.0
    @test_constr model[:eq_ac_pf]["s1", "l1", 1] "-384.615 vr[s1,b1,1]² + 384.615 vr[s1,b1,1]*vr[s1,b2,1] + 1923.077 vr[s1,b1,1]*vi[s1,b2,1] - 384.615 vi[s1,b1,1]² - 1923.077 vi[s1,b1,1]*vr[s1,b2,1] + 384.615 vi[s1,b1,1]*vi[s1,b2,1] + pf[s1,l1,1] = 0"
    @test_constr model[:eq_ac_pf]["s1", "l2", 1] "-453.515 vr[s1,b1,1]² + 476.19 vr[s1,b1,1]*vr[s1,b3,1] + 1428.571 vr[s1,b1,1]*vi[s1,b3,1] - 453.515 vi[s1,b1,1]² - 1428.571 vi[s1,b1,1]*vr[s1,b3,1] + 476.19 vi[s1,b1,1]*vi[s1,b3,1] + pf[s1,l2,1] = 0"
    @test_constr model[:eq_ac_pf]["s1", "l3", 1] "-821.918 vr[s1,b2,1]² + 821.918 vr[s1,b2,1]*vr[s1,b3,1] + 2191.781 vr[s1,b2,1]*vi[s1,b3,1] - 821.918 vi[s1,b2,1]² - 2191.781 vi[s1,b2,1]*vr[s1,b3,1] + 821.918 vi[s1,b2,1]*vi[s1,b3,1] + pf[s1,l3,1] = 0"
    @test_constr model[:eq_ac_qf]["s1", "l1", 1] "-1921.077 vr[s1,b1,1]² + 1923.077 vr[s1,b1,1]*vr[s1,b2,1] - 384.615 vr[s1,b1,1]*vi[s1,b2,1] - 1921.077 vi[s1,b1,1]² + 384.615 vi[s1,b1,1]*vr[s1,b2,1] + 1923.077 vi[s1,b1,1]*vi[s1,b2,1] + qf[s1,l1,1] = 0"
    @test_constr model[:eq_ac_qf]["s1", "l2", 1] "-1359.184 vr[s1,b1,1]² + 1428.571 vr[s1,b1,1]*vr[s1,b3,1] - 476.19 vr[s1,b1,1]*vi[s1,b3,1] - 1359.184 vi[s1,b1,1]² + 476.19 vi[s1,b1,1]*vr[s1,b3,1] + 1428.571 vi[s1,b1,1]*vi[s1,b3,1] + qf[s1,l2,1] = 0"
    @test_constr model[:eq_ac_qf]["s1", "l3", 1] "-2190.531 vr[s1,b2,1]² + 2191.781 vr[s1,b2,1]*vr[s1,b3,1] - 821.918 vr[s1,b2,1]*vi[s1,b3,1] - 2190.531 vi[s1,b2,1]² + 821.918 vi[s1,b2,1]*vr[s1,b3,1] + 2191.781 vi[s1,b2,1]*vi[s1,b3,1] + qf[s1,l3,1] = 0"
    @test_constr model[:eq_ac_pt]["s1", "l1", 1] "384.615 vr[s1,b1,1]*vr[s1,b2,1] - 1923.077 vr[s1,b1,1]*vi[s1,b2,1] + 1923.077 vi[s1,b1,1]*vr[s1,b2,1] + 384.615 vi[s1,b1,1]*vi[s1,b2,1] - 384.615 vr[s1,b2,1]² - 384.615 vi[s1,b2,1]² + pt[s1,l1,1] = 0"
    @test_constr model[:eq_ac_pt]["s1", "l2", 1] "476.19 vr[s1,b1,1]*vr[s1,b3,1] - 1428.571 vr[s1,b1,1]*vi[s1,b3,1] + 1428.571 vi[s1,b1,1]*vr[s1,b3,1] + 476.19 vi[s1,b1,1]*vi[s1,b3,1] - 500 vr[s1,b3,1]² - 500 vi[s1,b3,1]² + pt[s1,l2,1] = 0"
    @test_constr model[:eq_ac_pt]["s1", "l3", 1] "821.918 vr[s1,b2,1]*vr[s1,b3,1] - 2191.781 vr[s1,b2,1]*vi[s1,b3,1] + 2191.781 vi[s1,b2,1]*vr[s1,b3,1] + 821.918 vi[s1,b2,1]*vi[s1,b3,1] - 821.918 vr[s1,b3,1]² - 821.918 vi[s1,b3,1]² + pt[s1,l3,1] = 0"
    @test_constr model[:eq_ac_qt]["s1", "l1", 1] "1923.077 vr[s1,b1,1]*vr[s1,b2,1] + 384.615 vr[s1,b1,1]*vi[s1,b2,1] - 384.615 vi[s1,b1,1]*vr[s1,b2,1] + 1923.077 vi[s1,b1,1]*vi[s1,b2,1] - 1921.077 vr[s1,b2,1]² - 1921.077 vi[s1,b2,1]² + qt[s1,l1,1] = 0"
    @test_constr model[:eq_ac_qt]["s1", "l2", 1] "1428.571 vr[s1,b1,1]*vr[s1,b3,1] + 476.19 vr[s1,b1,1]*vi[s1,b3,1] - 476.19 vi[s1,b1,1]*vr[s1,b3,1] + 1428.571 vi[s1,b1,1]*vi[s1,b3,1] - 1498.5 vr[s1,b3,1]² - 1498.5 vi[s1,b3,1]² + qt[s1,l2,1] = 0"
    @test_constr model[:eq_ac_qt]["s1", "l3", 1] "2191.781 vr[s1,b2,1]*vr[s1,b3,1] + 821.918 vr[s1,b2,1]*vi[s1,b3,1] - 821.918 vi[s1,b2,1]*vr[s1,b3,1] + 2191.781 vi[s1,b2,1]*vi[s1,b3,1] - 2190.531 vr[s1,b3,1]² - 2190.531 vi[s1,b3,1]² + qt[s1,l3,1] = 0"

    # Flow limit constraints
    # -------------------------------------------------------------------------
    @test_constr model[:eq_flow_limit_fr_ub]["s1", "l1", 1] "pf[s1,l1,1]² + qf[s1,l1,1]² - overflow[s1,l1,1]² - 300 overflow[s1,l1,1] ≤ 22500"
    @test_constr model[:eq_flow_limit_fr_ub]["s1", "l2", 1] "pf[s1,l2,1]² + qf[s1,l2,1]² - overflow[s1,l2,1]² - 200 overflow[s1,l2,1] ≤ 10000"
    @test_constr model[:eq_flow_limit_fr_ub]["s1", "l3", 1] "pf[s1,l3,1]² + qf[s1,l3,1]² - overflow[s1,l3,1]² - 240 overflow[s1,l3,1] ≤ 14400"
    @test_constr model[:eq_flow_limit_to_ub]["s1", "l1", 1] "pt[s1,l1,1]² + qt[s1,l1,1]² - overflow[s1,l1,1]² - 300 overflow[s1,l1,1] ≤ 22500"
    @test_constr model[:eq_flow_limit_to_ub]["s1", "l2", 1] "pt[s1,l2,1]² + qt[s1,l2,1]² - overflow[s1,l2,1]² - 200 overflow[s1,l2,1] ≤ 10000"
    @test_constr model[:eq_flow_limit_to_ub]["s1", "l3", 1] "pt[s1,l3,1]² + qt[s1,l3,1]² - overflow[s1,l3,1]² - 240 overflow[s1,l3,1] ≤ 14400"

    # Angle difference constraints
    # -------------------------------------------------------------------------
    @test_constr model[:eq_angle_diff_lb]["s1", "l1", 1] "-0.577 vr[s1,b1,1]*vr[s1,b2,1] + vr[s1,b1,1]*vi[s1,b2,1] - vi[s1,b1,1]*vr[s1,b2,1] - 0.577 vi[s1,b1,1]*vi[s1,b2,1] ≤ 0"
    @test_constr model[:eq_angle_diff_lb]["s1", "l2", 1] "-0.577 vr[s1,b1,1]*vr[s1,b3,1] + vr[s1,b1,1]*vi[s1,b3,1] - vi[s1,b1,1]*vr[s1,b3,1] - 0.577 vi[s1,b1,1]*vi[s1,b3,1] ≤ 0"
    @test_constr model[:eq_angle_diff_lb]["s1", "l3", 1] "-0.577 vr[s1,b2,1]*vr[s1,b3,1] + vr[s1,b2,1]*vi[s1,b3,1] - vi[s1,b2,1]*vr[s1,b3,1] - 0.577 vi[s1,b2,1]*vi[s1,b3,1] ≤ 0"
    @test_constr model[:eq_angle_diff_ub]["s1", "l1", 1] "-0.577 vr[s1,b1,1]*vr[s1,b2,1] - vr[s1,b1,1]*vi[s1,b2,1] + vi[s1,b1,1]*vr[s1,b2,1] - 0.577 vi[s1,b1,1]*vi[s1,b2,1] ≤ 0"
    @test_constr model[:eq_angle_diff_ub]["s1", "l2", 1] "-0.577 vr[s1,b1,1]*vr[s1,b3,1] - vr[s1,b1,1]*vi[s1,b3,1] + vi[s1,b1,1]*vr[s1,b3,1] - 0.577 vi[s1,b1,1]*vi[s1,b3,1] ≤ 0"
    @test_constr model[:eq_angle_diff_ub]["s1", "l3", 1] "-0.577 vr[s1,b2,1]*vr[s1,b3,1] - vr[s1,b2,1]*vi[s1,b3,1] + vi[s1,b2,1]*vr[s1,b3,1] - 0.577 vi[s1,b2,1]*vi[s1,b3,1] ≤ 0"

    # Nodal balance constraints
    # -------------------------------------------------------------------------
    # b1: source of l1, l2
    @test_constr model[:eq_nodal_balance]["s1", "b1", 1] "ni[s1,b1,1] - pf[s1,l1,1] - pf[s1,l2,1] = 0"
    @test_constr model[:eq_reactive_nodal_balance]["s1", "b1", 1] "qi[s1,b1,1] - qf[s1,l1,1] - qf[s1,l2,1] = 0"
    # b2: target of l1, source of l3, has shunt sh1
    @test ("s1", "b2", 1) in keys(model[:eq_nodal_balance])
    @test ("s1", "b2", 1) in keys(model[:eq_reactive_nodal_balance])
    # b3: target of l2, l3
    @test_constr model[:eq_nodal_balance]["s1", "b3", 1] "ni[s1,b3,1] - pt[s1,l2,1] - pt[s1,l3,1] = 0"
    @test_constr model[:eq_reactive_nodal_balance]["s1", "b3", 1] "qi[s1,b3,1] - qt[s1,l2,1] - qt[s1,l3,1] = 0"

    # Power balance (delegated to CopperPlate)
    # -------------------------------------------------------------------------
    @test ("s1", 1) in keys(model[:eq_power_balance])
end

@testfunction transmission_ac_polar_build_test begin
    model =
        build_model(
            UnitCommitment.read(
                fixture("ac_3bus.json"),
                extensions = [
                    UnitCommitment.ACTransmissionExt(
                        formulation = UnitCommitment.ACPolar(),
                    ),
                ],
            ),
            optimizer = test_optimizer(),
            variable_names = true,
        ).inner

    # Voltage variables (ACP: vm, va)
    # -------------------------------------------------------------------------
    # All buses have vmin=0.95, vmax=1.05
    @test_continuous_var model[:vm]["s1", "b1", 1] lb = 0.95 ub = 1.05
    @test_continuous_var model[:vm]["s1", "b2", 1] lb = 0.95 ub = 1.05
    @test_continuous_var model[:vm]["s1", "b3", 1] lb = 0.95 ub = 1.05
    @test_continuous_var model[:va]["s1", "b1", 1]
    @test_continuous_var model[:va]["s1", "b2", 1]
    @test_continuous_var model[:va]["s1", "b3", 1]

    # Flow variables (pf, pt, qf, qt, overflow)
    # -------------------------------------------------------------------------
    @test_continuous_var model[:pf]["s1", "l1", 1]
    @test_continuous_var model[:pt]["s1", "l1", 1]
    @test_continuous_var model[:qf]["s1", "l1", 1]
    @test_continuous_var model[:qt]["s1", "l1", 1]
    @test_continuous_var model[:pf]["s1", "l2", 1]
    @test_continuous_var model[:pt]["s1", "l2", 1]
    @test_continuous_var model[:qf]["s1", "l2", 1]
    @test_continuous_var model[:qt]["s1", "l2", 1]
    @test_continuous_var model[:pf]["s1", "l3", 1]
    @test_continuous_var model[:pt]["s1", "l3", 1]
    @test_continuous_var model[:qf]["s1", "l3", 1]
    @test_continuous_var model[:qt]["s1", "l3", 1]
    @test_continuous_var model[:overflow]["s1", "l1", 1] lb = 0
    @test_continuous_var model[:overflow]["s1", "l2", 1] lb = 0
    @test_continuous_var model[:overflow]["s1", "l3", 1] lb = 0

    # No voltage magnitude constraints (ACP uses bounds on vm instead)
    # -------------------------------------------------------------------------
    @test :eq_voltage_mag_lb ∉ keys(object_dictionary(model))
    @test :eq_voltage_mag_ub ∉ keys(object_dictionary(model))

    # Voltage reference constraint (slack bus b1 only)
    # -------------------------------------------------------------------------
    @test_constr model[:eq_voltage_ref]["s1", "b1", 1] "va[s1,b1,1] = 0"
    @test ("s1", "b2", 1) ∉ keys(model[:eq_voltage_ref])
    @test ("s1", "b3", 1) ∉ keys(model[:eq_voltage_ref])

    # Ohm's law constraints
    # -------------------------------------------------------------------------
    # l1: b1 → b2, r=0.01, x=0.05, bs=0.04, tap=1.0, shift=0.0
    @test_constr model[:eq_ac_pf]["s1", "l1", 1] "pf[s1,l1,1] - (100 * (((3.846 vm[s1,b1,1]²) + (-3.846 * ((vm[s1,b1,1]*vm[s1,b2,1]) * cos(va[s1,b1,1] - va[s1,b2,1])))) + (19.231 * ((vm[s1,b1,1]*vm[s1,b2,1]) * sin(va[s1,b1,1] - va[s1,b2,1]))))) = 0"
    @test_constr model[:eq_ac_pf]["s1", "l2", 1] "pf[s1,l2,1] - (100 * (((4.535 vm[s1,b1,1]²) + (-4.762 * ((vm[s1,b1,1]*vm[s1,b3,1]) * cos(va[s1,b1,1] - va[s1,b3,1])))) + (14.286 * ((vm[s1,b1,1]*vm[s1,b3,1]) * sin(va[s1,b1,1] - va[s1,b3,1]))))) = 0"
    @test_constr model[:eq_ac_pf]["s1", "l3", 1] "pf[s1,l3,1] - (100 * (((8.219 vm[s1,b2,1]²) + (-8.219 * ((vm[s1,b2,1]*vm[s1,b3,1]) * cos(va[s1,b2,1] - va[s1,b3,1])))) + (21.918 * ((vm[s1,b2,1]*vm[s1,b3,1]) * sin(va[s1,b2,1] - va[s1,b3,1]))))) = 0"
    @test_constr model[:eq_ac_qf]["s1", "l1", 1] "qf[s1,l1,1] - (100 * (((19.211 vm[s1,b1,1]²) - (19.231 * ((vm[s1,b1,1]*vm[s1,b2,1]) * cos(va[s1,b1,1] - va[s1,b2,1])))) + (-3.846 * ((vm[s1,b1,1]*vm[s1,b2,1]) * sin(va[s1,b1,1] - va[s1,b2,1]))))) = 0"
    @test_constr model[:eq_ac_qf]["s1", "l2", 1] "qf[s1,l2,1] - (100 * (((13.592 vm[s1,b1,1]²) - (14.286 * ((vm[s1,b1,1]*vm[s1,b3,1]) * cos(va[s1,b1,1] - va[s1,b3,1])))) + (-4.762 * ((vm[s1,b1,1]*vm[s1,b3,1]) * sin(va[s1,b1,1] - va[s1,b3,1]))))) = 0"
    @test_constr model[:eq_ac_qf]["s1", "l3", 1] "qf[s1,l3,1] - (100 * (((21.905 vm[s1,b2,1]²) - (21.918 * ((vm[s1,b2,1]*vm[s1,b3,1]) * cos(va[s1,b2,1] - va[s1,b3,1])))) + (-8.219 * ((vm[s1,b2,1]*vm[s1,b3,1]) * sin(va[s1,b2,1] - va[s1,b3,1]))))) = 0"
    @test_constr model[:eq_ac_pt]["s1", "l1", 1] "pt[s1,l1,1] - (100 * (((3.846 vm[s1,b2,1]²) + (-3.846 * ((vm[s1,b1,1]*vm[s1,b2,1]) * cos(va[s1,b1,1] - va[s1,b2,1])))) + (-19.231 * ((vm[s1,b1,1]*vm[s1,b2,1]) * sin(va[s1,b1,1] - va[s1,b2,1]))))) = 0"
    @test_constr model[:eq_ac_pt]["s1", "l2", 1] "pt[s1,l2,1] - (100 * (((5 vm[s1,b3,1]²) + (-4.762 * ((vm[s1,b1,1]*vm[s1,b3,1]) * cos(va[s1,b1,1] - va[s1,b3,1])))) + (-14.286 * ((vm[s1,b1,1]*vm[s1,b3,1]) * sin(va[s1,b1,1] - va[s1,b3,1]))))) = 0"
    @test_constr model[:eq_ac_pt]["s1", "l3", 1] "pt[s1,l3,1] - (100 * (((8.219 vm[s1,b3,1]²) + (-8.219 * ((vm[s1,b2,1]*vm[s1,b3,1]) * cos(va[s1,b2,1] - va[s1,b3,1])))) + (-21.918 * ((vm[s1,b2,1]*vm[s1,b3,1]) * sin(va[s1,b2,1] - va[s1,b3,1]))))) = 0"
    @test_constr model[:eq_ac_qt]["s1", "l1", 1] "qt[s1,l1,1] - (100 * (((19.211 vm[s1,b2,1]²) - (19.231 * ((vm[s1,b1,1]*vm[s1,b2,1]) * cos(va[s1,b1,1] - va[s1,b2,1])))) + (3.846 * ((vm[s1,b1,1]*vm[s1,b2,1]) * sin(va[s1,b1,1] - va[s1,b2,1]))))) = 0"
    @test_constr model[:eq_ac_qt]["s1", "l2", 1] "qt[s1,l2,1] - (100 * (((14.985 vm[s1,b3,1]²) - (14.286 * ((vm[s1,b1,1]*vm[s1,b3,1]) * cos(va[s1,b1,1] - va[s1,b3,1])))) + (4.762 * ((vm[s1,b1,1]*vm[s1,b3,1]) * sin(va[s1,b1,1] - va[s1,b3,1]))))) = 0"
    @test_constr model[:eq_ac_qt]["s1", "l3", 1] "qt[s1,l3,1] - (100 * (((21.905 vm[s1,b3,1]²) - (21.918 * ((vm[s1,b2,1]*vm[s1,b3,1]) * cos(va[s1,b2,1] - va[s1,b3,1])))) + (8.219 * ((vm[s1,b2,1]*vm[s1,b3,1]) * sin(va[s1,b2,1] - va[s1,b3,1]))))) = 0"

    # Flow limit constraints
    # -------------------------------------------------------------------------
    @test_constr model[:eq_flow_limit_fr_ub]["s1", "l1", 1] "pf[s1,l1,1]² + qf[s1,l1,1]² - overflow[s1,l1,1]² - 300 overflow[s1,l1,1] ≤ 22500"
    @test_constr model[:eq_flow_limit_fr_ub]["s1", "l2", 1] "pf[s1,l2,1]² + qf[s1,l2,1]² - overflow[s1,l2,1]² - 200 overflow[s1,l2,1] ≤ 10000"
    @test_constr model[:eq_flow_limit_fr_ub]["s1", "l3", 1] "pf[s1,l3,1]² + qf[s1,l3,1]² - overflow[s1,l3,1]² - 240 overflow[s1,l3,1] ≤ 14400"
    @test_constr model[:eq_flow_limit_to_ub]["s1", "l1", 1] "pt[s1,l1,1]² + qt[s1,l1,1]² - overflow[s1,l1,1]² - 300 overflow[s1,l1,1] ≤ 22500"
    @test_constr model[:eq_flow_limit_to_ub]["s1", "l2", 1] "pt[s1,l2,1]² + qt[s1,l2,1]² - overflow[s1,l2,1]² - 200 overflow[s1,l2,1] ≤ 10000"
    @test_constr model[:eq_flow_limit_to_ub]["s1", "l3", 1] "pt[s1,l3,1]² + qt[s1,l3,1]² - overflow[s1,l3,1]² - 240 overflow[s1,l3,1] ≤ 14400"

    # Angle difference constraints
    # -------------------------------------------------------------------------
    @test_constr model[:eq_angle_diff_lb]["s1", "l1", 1] "-va[s1,b1,1] + va[s1,b2,1] ≤ 0.524"
    @test_constr model[:eq_angle_diff_lb]["s1", "l2", 1] "-va[s1,b1,1] + va[s1,b3,1] ≤ 0.524"
    @test_constr model[:eq_angle_diff_lb]["s1", "l3", 1] "-va[s1,b2,1] + va[s1,b3,1] ≤ 0.524"
    @test_constr model[:eq_angle_diff_ub]["s1", "l1", 1] "va[s1,b1,1] - va[s1,b2,1] ≤ 0.524"
    @test_constr model[:eq_angle_diff_ub]["s1", "l2", 1] "va[s1,b1,1] - va[s1,b3,1] ≤ 0.524"
    @test_constr model[:eq_angle_diff_ub]["s1", "l3", 1] "va[s1,b2,1] - va[s1,b3,1] ≤ 0.524"

    # Nodal balance constraints
    # -------------------------------------------------------------------------
    # b1: source of l1, l2
    @test_constr model[:eq_nodal_balance]["s1", "b1", 1] "ni[s1,b1,1] - pf[s1,l1,1] - pf[s1,l2,1] = 0"
    @test_constr model[:eq_reactive_nodal_balance]["s1", "b1", 1] "qi[s1,b1,1] - qf[s1,l1,1] - qf[s1,l2,1] = 0"
    # b2: target of l1, source of l3, has shunt sh1
    @test ("s1", "b2", 1) in keys(model[:eq_nodal_balance])
    @test ("s1", "b2", 1) in keys(model[:eq_reactive_nodal_balance])
    # b3: target of l2, l3
    @test_constr model[:eq_nodal_balance]["s1", "b3", 1] "ni[s1,b3,1] - pt[s1,l2,1] - pt[s1,l3,1] = 0"
    @test_constr model[:eq_reactive_nodal_balance]["s1", "b3", 1] "qi[s1,b3,1] - qt[s1,l2,1] - qt[s1,l3,1] = 0"

    # Power balance (delegated to CopperPlate)
    # -------------------------------------------------------------------------
    @test ("s1", 1) in keys(model[:eq_power_balance])
end
