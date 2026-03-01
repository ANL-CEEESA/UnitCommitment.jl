# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using UnitCommitment
using JSON
using Ipopt
using Juniper
using JuMP

function _pm_solution_to_ucjl(pm_sol::Dict, instance::UnitCommitmentInstance)
    sc = instance.scenarios[1]
    sol_data = pm_sol["solution"]
    if get(sol_data, "multinetwork", false)
        sol_data = sol_data["nw"][first(keys(sol_data["nw"]))]
    end
    base_mva = sol_data["baseMVA"]
    branches_sol = get(sol_data, "branch", nothing)

    @assert branches_sol !== nothing "PM solution missing branch flow data"

    bus_vm = OrderedDict{String,Vector{Float64}}()
    bus_va = OrderedDict{String,Vector{Float64}}()
    for (bus_id, bus_data) in sol_data["bus"]
        name = "b$bus_id"
        bus_vm[name] = [bus_data["vm"]]
        bus_va[name] = [bus_data["va"]]
    end

    line_pf = OrderedDict{String,Vector{Float64}}()
    line_qf = OrderedDict{String,Vector{Float64}}()
    line_pt = OrderedDict{String,Vector{Float64}}()
    line_qt = OrderedDict{String,Vector{Float64}}()
    line_overflow = OrderedDict{String,Vector{Float64}}()
    for (br_id, br_data) in branches_sol
        name = "l$br_id"
        line_pf[name] = [br_data["pf"] * base_mva]
        line_qf[name] = [br_data["qf"] * base_mva]
        line_pt[name] = [br_data["pt"] * base_mva]
        line_qt[name] = [br_data["qt"] * base_mva]
        line_overflow[name] = [0.0]
    end

    return Dict(
        sc.name => Dict(
            "Bus: Voltage magnitude (p.u.)" => bus_vm,
            "Bus: Voltage angle (rad)" => bus_va,
            "Branch: Base active flow from-end (MW)" => line_pf,
            "Branch: Base reactive flow from-end (MVAr)" => line_qf,
            "Branch: Base active flow to-end (MW)" => line_pt,
            "Branch: Base reactive flow to-end (MVAr)" => line_qt,
            "Branch: Overflow (MW)" => line_overflow,
        ),
    )
end

function _validate_pm_case(case_name::String)
    instance = UnitCommitment.read(
        fixture("powermodels/$case_name/converted.json"),
        extensions = [UnitCommitment.ACTransmissionExt()],
    )
    pm_sol = JSON.parsefile(fixture("powermodels/$case_name/sol_ac_opf.json"))
    sol = _pm_solution_to_ucjl(pm_sol, instance)
    @test UnitCommitment.validate(
        instance,
        sol,
        UnitCommitment.ACTransmissionExt(),
        tol = 0.05,
    ) == 0
end

function _warm_start!(model, pm_sol, ::UnitCommitment.ACPolar)
    for (bus_id, bus_data) in pm_sol["bus"]
        set_start_value(model.inner[:vm]["s1", "b$bus_id", 1], bus_data["vm"])
        set_start_value(model.inner[:va]["s1", "b$bus_id", 1], bus_data["va"])
    end
    return _warm_start_flows!(model, pm_sol)
end

function _warm_start!(model, pm_sol, ::UnitCommitment.ACRectangular)
    for (bus_id, bus_data) in pm_sol["bus"]
        vm, va = bus_data["vm"], bus_data["va"]
        set_start_value(model.inner[:vr]["s1", "b$bus_id", 1], vm * cos(va))
        set_start_value(model.inner[:vi]["s1", "b$bus_id", 1], vm * sin(va))
    end
    return _warm_start_flows!(model, pm_sol)
end

function _warm_start_flows!(model, pm_sol)
    baseMVA = pm_sol["baseMVA"]
    for (br_id, br_data) in pm_sol["branch"]
        name = "l$br_id"
        set_start_value(
            model.inner[:pf]["s1", name, 1],
            br_data["pf"] * baseMVA,
        )
        set_start_value(
            model.inner[:qf]["s1", name, 1],
            br_data["qf"] * baseMVA,
        )
        set_start_value(
            model.inner[:pt]["s1", name, 1],
            br_data["pt"] * baseMVA,
        )
        set_start_value(
            model.inner[:qt]["s1", name, 1],
            br_data["qt"] * baseMVA,
        )
    end
end

function _validate_ac_opf(
    case_name::String;
    formulation = UnitCommitment.ACRectangular(),
    multinetwork = false,
    atol_obj = 10.0,
    atol_mw = 1.0,
    atol_mvar = 1.0,
    atol_vm = 0.005,
    atol_rad = 0.005,
)
    pm = JSON.parsefile(fixture("powermodels/$case_name/sol_ac_opf.json"))
    pm_sol = multinetwork ? pm["solution"]["nw"]["1"] : pm["solution"]
    baseMVA = pm_sol["baseMVA"]

    instance = UnitCommitment.read(
        fixture("powermodels/$case_name/converted.json"),
        extensions = [
            UnitCommitment.ACTransmissionExt(formulation = formulation),
            UnitCommitment.NoLMP(),
        ],
    )
    model = build_model(instance, optimizer = _nlp_optimizer())
    _warm_start!(model, pm_sol, formulation)
    UnitCommitment.optimize!(model)
    sol = solution(model)

    # Objective
    @test abs(objective_value(model.inner) - pm["objective"]) < atol_obj

    # Generator active dispatch
    for (gen_id, gen_data) in pm_sol["gen"]
        uc_name = "g$gen_id"
        pm_pg_mw = gen_data["pg"] * baseMVA
        uc_pg_mw = sol["Thermal: Production (MW)"][uc_name][1]
        @test abs(uc_pg_mw - pm_pg_mw) < atol_mw
    end

    # Branch flows (active and reactive, from and to)
    for (br_id, br_data) in pm_sol["branch"]
        uc_name = "l$br_id"
        @test abs(
            sol["Branch: Base active flow from-end (MW)"][uc_name][1] -
            br_data["pf"] * baseMVA,
        ) < atol_mw
        @test abs(
            sol["Branch: Base reactive flow from-end (MVAr)"][uc_name][1] -
            br_data["qf"] * baseMVA,
        ) < atol_mvar
        @test abs(
            sol["Branch: Base active flow to-end (MW)"][uc_name][1] -
            br_data["pt"] * baseMVA,
        ) < atol_mw
        @test abs(
            sol["Branch: Base reactive flow to-end (MVAr)"][uc_name][1] -
            br_data["qt"] * baseMVA,
        ) < atol_mvar
    end

    # Bus voltages (magnitude and angle)
    for (bus_id, bus_data) in pm_sol["bus"]
        uc_name = "b$bus_id"
        @test abs(
            sol["Bus: Voltage magnitude (p.u.)"][uc_name][1] - bus_data["vm"],
        ) < atol_vm
        @test abs(
            sol["Bus: Voltage angle (rad)"][uc_name][1] - bus_data["va"],
        ) < atol_rad
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

# --- Validation tests (PowerModels reference solutions) ---

@testfunction transmission_ac_validate_pm_case5_test begin
    _validate_pm_case("case5")
end

@testfunction transmission_ac_validate_pm_case14_test begin
    _validate_pm_case("case14")
end

@testfunction transmission_ac_validate_pm_case5_pwlc_test begin
    _validate_pm_case("case5_pwlc")
end

@testfunction transmission_ac_validate_pm_case5_strg_test begin
    _validate_pm_case("case5_strg")
end

# --- Solve + compare tests (against PowerModels AC-OPF) ---

@testfunction transmission_ac_solve_case5_polar_test begin
    _validate_ac_opf("case5", formulation = UnitCommitment.ACPolar())
end

@testfunction transmission_ac_solve_case5_rect_test begin
    _validate_ac_opf("case5")
end

@testfunction transmission_ac_solve_case14_pwl_polar_test begin
    _validate_ac_opf("case14_pwl", formulation = UnitCommitment.ACPolar())
end

@testfunction transmission_ac_solve_case14_pwl_rect_test begin
    _validate_ac_opf("case14_pwl")
end
