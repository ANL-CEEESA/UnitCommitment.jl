# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using HiGHS, Ipopt, Juniper, JuMP, JSON, UnitCommitment

function _load_pm_solution(case_name)
    path = fixture("powermodels/$case_name/sol_dc_opf.json")
    return JSON.parsefile(path)
end

function _validate_dc_opf(
    case_name;
    multinetwork = false,
    optimizer = test_optimizer(),
    atol_obj = 1.0,
    atol_mw = 0.1,
    atol_rad = 1e-4,
)
    pm = _load_pm_solution(case_name)
    pm_sol = multinetwork ? pm["solution"]["nw"]["1"] : pm["solution"]
    baseMVA = pm_sol["baseMVA"]

    instance = UnitCommitment.read(
        fixture("powermodels/$case_name/converted.json"),
        extensions = [
            UnitCommitment.PhaseAngleTransmissionExt(),
            UnitCommitment.NoLMP(),
        ],
    )
    model = build_model(instance, optimizer = optimizer)
    optimize!(model)
    sol = solution(model)

    # Objective
    @test abs(objective_value(model.inner) - pm["objective"]) < atol_obj

    # Generator dispatch
    for (gen_id, gen_data) in pm_sol["gen"]
        uc_name = "g$gen_id"
        pm_pg_mw = gen_data["pg"] * baseMVA
        uc_pg_mw = sol["Thermal: Production (MW)"][uc_name][1]
        @test abs(uc_pg_mw - pm_pg_mw) < atol_mw
    end

    # Branch flows
    for (br_id, br_data) in pm_sol["branch"]
        uc_name = "l$br_id"
        pm_pf_mw = br_data["pf"] * baseMVA
        uc_flow_mw = sol["Branch: Base flow (MW)"][uc_name][1]
        @test abs(uc_flow_mw - pm_pf_mw) < atol_mw
    end

    # Bus voltage angles
    for (bus_id, bus_data) in pm_sol["bus"]
        uc_name = "b$bus_id"
        pm_va = bus_data["va"]
        uc_va = sol["Bus: Voltage angle (rad)"][uc_name][1]
        @test abs(uc_va - pm_va) < atol_rad
    end

    # Zero overflow
    for (_, overflow_ts) in sol["Branch: Overflow (MW)"]
        @test all(v -> abs(v) < atol_mw, overflow_ts)
    end

    # Zero curtailment
    for (_, curtail_ts) in sol["Bus: Load curtail (MW)"]
        @test all(v -> abs(v) < atol_mw, curtail_ts)
    end
end

@testfunction transmission_dc_phaseangle_powermodels_case5_test begin
    _validate_dc_opf("case5")
end

@testfunction transmission_dc_phaseangle_powermodels_case5_gs_test begin
    _validate_dc_opf("case5_gs")
end

@testfunction transmission_dc_phaseangle_powermodels_case14_test begin
    _validate_dc_opf("case14_pwl")
end

@testfunction transmission_dc_phaseangle_powermodels_case5_strg_test begin
    _validate_dc_opf(
        "case5_strg",
        multinetwork = true,
        optimizer = _minlp_optimizer(),
    )
end

# case5_pwlc: Skipped — DC lines not supported in UC.jl conversion
