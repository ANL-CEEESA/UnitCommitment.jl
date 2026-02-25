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

function _minlp_optimizer()
    ipopt = optimizer_with_attributes(
        Ipopt.Optimizer,
        "print_level" => 0,
        "sb" => "yes",
    )
    highs = optimizer_with_attributes(HiGHS.Optimizer, "output_flag" => false)
    return optimizer_with_attributes(
        Juniper.Optimizer,
        "nl_solver" => ipopt,
        "mip_solver" => highs,
        "log_levels" => [],
    )
end

function _warm_start!(model, case_name, ::UnitCommitment.ACPolar)
    pm_sol = JSON.parsefile(fixture("powermodels/$case_name/sol_ac_opf.json"))
    for (bus_id, bus_data) in pm_sol["solution"]["bus"]
        set_start_value(model.inner[:vm]["s1", "b$bus_id", 1], bus_data["vm"])
        set_start_value(model.inner[:va]["s1", "b$bus_id", 1], bus_data["va"])
    end
end

function _warm_start!(model, case_name, ::UnitCommitment.ACRectangular)
    pm_sol = JSON.parsefile(fixture("powermodels/$case_name/sol_ac_opf.json"))
    for (bus_id, bus_data) in pm_sol["solution"]["bus"]
        vm, va = bus_data["vm"], bus_data["va"]
        set_start_value(model.inner[:vr]["s1", "b$bus_id", 1], vm * cos(va))
        set_start_value(model.inner[:vi]["s1", "b$bus_id", 1], vm * sin(va))
    end
end

function _solve_ac_case(
    case_name::String;
    formulation = UnitCommitment.ACRectangular(),
)
    instance = UnitCommitment.read(
        fixture("powermodels/$case_name/converted.json"),
        extensions = [
            UnitCommitment.ACTransmissionExt(formulation = formulation),
            UnitCommitment.NoLMP(),
        ],
    )
    model = build_model(instance, optimizer = _minlp_optimizer())
    _warm_start!(model, case_name, formulation)
    return UnitCommitment.optimize!(model)
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

# --- Solve tests (build, solve, validate) ---

@testfunction transmission_ac_solve_case5_polar_test begin
    _solve_ac_case("case5", formulation = UnitCommitment.ACPolar())
end

@testfunction transmission_ac_solve_case5_rect_test begin
    _solve_ac_case("case5")
end

@testfunction transmission_ac_solve_case14_polar_test begin
    _solve_ac_case("case14", formulation = UnitCommitment.ACPolar())
end

@testfunction transmission_ac_solve_case14_rect_test begin
    _solve_ac_case("case14")
end
