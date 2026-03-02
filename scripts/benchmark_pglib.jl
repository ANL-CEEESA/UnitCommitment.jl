#!/usr/bin/env julia
#
# Benchmarks UnitCommitment.jl against PowerModels.jl on pglib-opf instances.
#
# Usage:
#   julia --project=test scripts/benchmark_pglib.jl [--cases PATTERN]
#
# Requires the test project environment (test/Project.toml).

using UnitCommitment
using JuMP
using JSON
using Ipopt
using HiGHS
using DataStructures: OrderedDict
using Printf

include(joinpath(@__DIR__, "matpower_to_ucjl.jl"))

# ── Constants ──────────────────────────────────────────────────────────

const CASES = [
    "pglib_opf_case3_lmbd",
    "pglib_opf_case5_pjm",
    "pglib_opf_case14_ieee",
    "pglib_opf_case30_ieee",
    "pglib_opf_case57_ieee",
    "pglib_opf_case118_ieee",
    "pglib_opf_case300_ieee",
    "pglib_opf_case1354_pegase",
    "pglib_opf_case2869_pegase",
]

const ROOT = joinpath(@__DIR__, "..")
const PGLIB_DIR = joinpath(ROOT, "local", "pglib-opf")
const CONVERTED_DIR = joinpath(ROOT, "local", "pm-benchmark", "converted")
const RESULTS_DIR = joinpath(ROOT, "local", "pm-benchmark", "results")

# ── Formulation definitions ────────────────────────────────────────────

struct FormulationSpec
    name::String
    extensions::Vector{UnitCommitment.UnitCommitmentExtension}
    solver::Any
    solver_attrs::Vector{Pair{String,Any}}
    pm_sol_file::String
end

function _make_formulations()
    ipopt_attrs = Pair{String,Any}[
        "tol" => 1e-6,
        "print_level" => 0,
        "sb" => "yes",
    ]
    highs_attrs = Pair{String,Any}[
        "output_flag" => false,
    ]
    return [
        FormulationSpec(
            "ac_polar",
            UnitCommitment.UnitCommitmentExtension[
                UnitCommitment.ACTransmissionExt(
                    formulation = UnitCommitment.ACPolar(),
                ),
                UnitCommitment.NoLMP(),
            ],
            Ipopt.Optimizer,
            ipopt_attrs,
            "sol_ac_opf.json",
        ),
        FormulationSpec(
            "ac_rect",
            UnitCommitment.UnitCommitmentExtension[
                UnitCommitment.ACTransmissionExt(
                    formulation = UnitCommitment.ACRectangular(),
                ),
                UnitCommitment.NoLMP(),
            ],
            Ipopt.Optimizer,
            ipopt_attrs,
            "sol_ac_opf.json",
        ),
        FormulationSpec(
            "dc_phase",
            UnitCommitment.UnitCommitmentExtension[
                UnitCommitment.PhaseAngleTransmissionExt(),
                UnitCommitment.NoLMP(),
            ],
            HiGHS.Optimizer,
            highs_attrs,
            "sol_dc_opf.json",
        ),
        FormulationSpec(
            "dc_shift",
            UnitCommitment.UnitCommitmentExtension[
                UnitCommitment.ShiftFactorsTransmissionExt(
                    lazy = false,
                ),
                UnitCommitment.NoLMP(),
            ],
            HiGHS.Optimizer,
            highs_attrs,
            "sol_dc_opf.json",
        ),
    ]
end

# ── Helpers ────────────────────────────────────────────────────────────

function _count_constraints(m::JuMP.Model)
    return sum(
        JuMP.num_constraints(m, F, S)
        for (F, S) in JuMP.list_of_constraint_types(m);
        init = 0,
    )
end

function _make_optimizer(spec::FormulationSpec; log_file = nothing)
    attrs = copy(spec.solver_attrs)
    if log_file !== nothing
        if spec.solver == Ipopt.Optimizer
            # Replace silent attrs with logging attrs
            filter!(p -> p.first != "print_level", attrs)
            filter!(p -> p.first != "sb", attrs)
            push!(attrs, "print_level" => 5)
            push!(attrs, "output_file" => log_file)
        elseif spec.solver == HiGHS.Optimizer
            filter!(p -> p.first != "output_flag", attrs)
            push!(attrs, "output_flag" => true)
            push!(attrs, "log_file" => log_file)
        end
    end
    return optimizer_with_attributes(spec.solver, attrs...)
end

function _is_solved(status::AbstractString)
    return status in (
        "OPTIMAL",
        "LOCALLY_SOLVED",
        "ALMOST_OPTIMAL",
        "ALMOST_LOCALLY_SOLVED",
    )
end

function _fmt(v, digits = 2)
    if v isa Number && !isnan(v)
        return string(round(v; digits = digits))
    else
        return "-"
    end
end

function _csv_val(v)
    if v isa AbstractString
        return v
    elseif v isa Number
        return isnan(v) ? "" : string(v)
    else
        return string(v)
    end
end

# ── Step 1: Clone pglib-opf ───────────────────────────────────────────

function _ensure_pglib()
    if isdir(PGLIB_DIR)
        println("pglib-opf already cloned: $PGLIB_DIR")
        return nothing
    end
    println("Cloning pglib-opf...")
    run(
        `git clone --depth 1 --branch v23.07
         https://github.com/power-grid-lib/pglib-opf.git
         $PGLIB_DIR`,
    )
    return nothing
end

# ── Step 2: Convert cases ─────────────────────────────────────────────

function _convert_cases(cases::Vector{String})
    for case_name in cases
        case_dir = joinpath(CONVERTED_DIR, case_name)
        if isfile(joinpath(case_dir, "converted.json"))
            println("Already converted: $case_name")
            continue
        end
        input_file = joinpath(PGLIB_DIR, "$case_name.m")
        if !isfile(input_file)
            @warn "MATPOWER file not found" path = input_file
            continue
        end
        println("\nConverting: $case_name")
        matpower_to_ucjl(
            input_file,
            case_dir;
            relax_angle_diffs = true,
            power_balance_penalty = -1.0,
            flow_limit_penalty = -1.0,
        )
    end
    return nothing
end

# ── Step 3: Warm up ───────────────────────────────────────────────────

function _warmup(cases, formulations)
    warmup_case = cases[1]
    json_path = joinpath(CONVERTED_DIR, warmup_case, "converted.json")
    if !isfile(json_path)
        @warn "Cannot warm up: converted JSON not found" path = json_path
        return nothing
    end
    println("\n=== Warming up Julia ($warmup_case) ===")
    for spec in formulations
        print("  $(spec.name)... ")
        opt = _make_optimizer(spec)
        try
            inst = UnitCommitment.read(
                json_path;
                extensions = spec.extensions,
            )
            mdl = UnitCommitment.build_model(inst; optimizer = opt)
            UnitCommitment.optimize!(mdl)
            println("ok")
        catch e
            println("FAILED")
            @warn "Warm-up failed" formulation = spec.name exception =
                (e, catch_backtrace())
        end
    end
    return nothing
end

# ── Step 4: Timed runs ────────────────────────────────────────────────

function _load_pm_stats(case_dir, pm_sol_file)
    pm_sol_path = joinpath(case_dir, pm_sol_file)
    pm = Dict{String,Any}(
        "obj" => NaN,
        "status" => "UNKNOWN",
        "vars" => 0,
        "constrs" => 0,
        "parse_time" => NaN,
        "build_time" => NaN,
        "optimize_time" => NaN,
    )
    if !isfile(pm_sol_path)
        @warn "PM solution not found" path = pm_sol_path
        return pm
    end
    sol = JSON.parsefile(pm_sol_path)
    pm["status"] = get(sol, "termination_status", "UNKNOWN")
    if _is_solved(pm["status"])
        obj = get(sol, "objective", nothing)
        if obj !== nothing
            pm["obj"] = obj
        end
    end
    if haskey(sol, "stats")
        s = sol["stats"]
        pm["parse_time"] = get(s, "parse_time", NaN)
        pm["build_time"] = get(s, "build_time", NaN)
        pm["optimize_time"] = get(s, "optimize_time", NaN)
        pm["vars"] = get(s, "num_variables", 0)
        pm["constrs"] = get(s, "num_constraints", 0)
    end
    return pm
end

function _solve_uc(
    json_path,
    spec;
    log_file = nothing,
    model_file = nothing,
)
    opt = _make_optimizer(spec; log_file = log_file)
    uc = Dict{String,Any}(
        "obj" => NaN,
        "status" => "UNKNOWN",
        "vars" => 0,
        "constrs" => 0,
        "read_time" => NaN,
        "build_time" => NaN,
        "optimize_time" => NaN,
    )
    t_read = @elapsed begin
        instance = UnitCommitment.read(
            json_path;
            extensions = spec.extensions,
        )
    end
    t_build = @elapsed begin
        model = UnitCommitment.build_model(
            instance;
            optimizer = opt,
            variable_names = true,
        )
    end
    uc["vars"] = JuMP.num_variables(model.inner)
    uc["constrs"] = _count_constraints(model.inner)
    if model_file !== nothing
        JuMP.write_to_file(model.inner, model_file)
        println("  Saved model: $model_file")
    end
    t_optimize = @elapsed begin
        UnitCommitment.optimize!(model)
    end
    uc["read_time"] = t_read
    uc["build_time"] = t_build
    uc["optimize_time"] = t_optimize
    uc["status"] = string(JuMP.termination_status(model.inner))
    if _is_solved(uc["status"])
        uc["obj"] = JuMP.objective_value(model.inner)
    end
    return uc
end

function _run_benchmarks(cases, formulations)
    results = OrderedDict{String,Any}[]
    for case_name in cases
        case_dir = joinpath(CONVERTED_DIR, case_name)
        json_path = joinpath(case_dir, "converted.json")
        if !isfile(json_path)
            @warn "Converted JSON not found" path = json_path
            continue
        end

        json_data = JSON.parsefile(json_path)
        n_buses = length(get(json_data, "Buses", Dict()))
        n_branches = length(get(json_data, "Branches", Dict()))
        n_generators = length(get(json_data, "Generators", Dict()))

        for spec in formulations
            println(
                "\n=== $case_name / $(spec.name) ===",
            )

            pm = _load_pm_stats(case_dir, spec.pm_sol_file)

            uc = Dict{String,Any}(
                "obj" => NaN,
                "status" => "UNKNOWN",
                "vars" => 0,
                "constrs" => 0,
                "read_time" => NaN,
                "build_time" => NaN,
                "optimize_time" => NaN,
            )
            result_dir = joinpath(
                RESULTS_DIR,
                case_name,
                spec.name,
            )
            mkpath(result_dir)
            log_file = joinpath(result_dir, "solve.log")
            model_file =
                joinpath(result_dir, "model.mof.json")
            try
                uc = _solve_uc(
                    json_path,
                    spec;
                    log_file = log_file,
                    model_file = model_file,
                )
            catch e
                @warn "UC.jl solve failed" case = case_name formulation =
                    spec.name exception = (e, catch_backtrace())
            end

            pm_solved = _is_solved(pm["status"])
            uc_solved = _is_solved(uc["status"])
            obj_gap_abs = NaN
            obj_gap_pct = NaN
            if pm_solved && uc_solved &&
               !isnan(pm["obj"]) &&
               !isnan(uc["obj"]) &&
               pm["obj"] != 0
                obj_gap_abs = abs(uc["obj"] - pm["obj"])
                obj_gap_pct = 100.0 * obj_gap_abs / abs(pm["obj"])
            end

            row = OrderedDict{String,Any}(
                "case" => case_name,
                "formulation" => spec.name,
                "buses" => n_buses,
                "branches" => n_branches,
                "generators" => n_generators,
                "pm_obj" => pm["obj"],
                "pm_status" => pm["status"],
                "pm_vars" => pm["vars"],
                "pm_constrs" => pm["constrs"],
                "pm_parse_time" => pm["parse_time"],
                "pm_build_time" => pm["build_time"],
                "pm_optimize_time" => pm["optimize_time"],
                "uc_obj" => uc["obj"],
                "uc_status" => uc["status"],
                "uc_vars" => uc["vars"],
                "uc_constrs" => uc["constrs"],
                "uc_read_time" => uc["read_time"],
                "uc_build_time" => uc["build_time"],
                "uc_optimize_time" => uc["optimize_time"],
                "obj_gap_pct" => obj_gap_pct,
                "obj_gap_abs" => obj_gap_abs,
            )
            push!(results, row)

            open(joinpath(result_dir, "result.json"), "w") do f
                JSON.print(f, row, 2)
                println(f)
            end

            pm_obj_str = pm_solved ? @sprintf("%.2f", pm["obj"]) : "N/A ($(pm["status"]))"
            uc_obj_str = uc_solved ? @sprintf("%.2f", uc["obj"]) : "N/A ($(uc["status"]))"
            gap_str = isnan(obj_gap_pct) ? "N/A" : @sprintf("%.4f%%", obj_gap_pct)
            @printf(
                "  PM: obj=%s, build=%.3fs, solve=%.3fs\n",
                pm_obj_str,
                pm["build_time"],
                pm["optimize_time"],
            )
            @printf(
                "  UC: obj=%s, build=%.3fs, solve=%.3fs\n",
                uc_obj_str,
                uc["build_time"],
                uc["optimize_time"],
            )
            println("  Gap: $gap_str")
        end
    end
    return results
end

# ── Step 5: Output generation ─────────────────────────────────────────

const CSV_COLUMNS = [
    "case",
    "formulation",
    "buses",
    "branches",
    "generators",
    "pm_obj",
    "pm_status",
    "pm_vars",
    "pm_constrs",
    "pm_parse_time",
    "pm_build_time",
    "pm_optimize_time",
    "uc_obj",
    "uc_status",
    "uc_vars",
    "uc_constrs",
    "uc_read_time",
    "uc_build_time",
    "uc_optimize_time",
    "obj_gap_pct",
    "obj_gap_abs",
]

function _write_csv(path, results)
    open(path, "w") do f
        println(f, join(CSV_COLUMNS, ","))
        for row in results
            vals = [_csv_val(get(row, c, "")) for c in CSV_COLUMNS]
            println(f, join(vals, ","))
        end
    end
    println("Wrote: $path")
    return nothing
end

function _write_markdown_tables(output_dir, results)
    for form_name in ["ac_polar", "ac_rect", "dc_phase", "dc_shift"]
        rows = filter(r -> r["formulation"] == form_name, results)
        isempty(rows) && continue

        path = joinpath(output_dir, "$form_name.md")
        open(path, "w") do f
            header = join(
                [
                    "| Case",
                    "Buses",
                    "PM Obj (\$/h)",
                    "UC.jl Obj (\$/h)",
                    "Gap (%)",
                    "PM Parse (s)",
                    "UC.jl Read (s)",
                    "PM Build (s)",
                    "UC.jl Build (s)",
                    "PM Solve (s)",
                    "UC.jl Solve (s)",
                    "PM Vars",
                    "UC.jl Vars",
                    "PM Constrs",
                    "UC.jl Constrs |",
                ],
                " | ",
            )
            sep = join(
                [
                    "|------|",
                    "------:|",
                    "-------------:|",
                    "----------------:|",
                    "--------:|",
                    "-------------:|",
                    "---------------:|",
                    "-------------:|",
                    "----------------:|",
                    "-------------:|",
                    "----------------:|",
                    "--------:|",
                    "-----------:|",
                    "-----------:|",
                    "--------------:|",
                ],
                "",
            )
            println(f, header)
            println(f, sep)
            for row in rows
                c = replace(row["case"], "pglib_opf_" => "")
                pm_solved = _is_solved(row["pm_status"])
                uc_solved = _is_solved(row["uc_status"])
                pm_obj_str = pm_solved ? _fmt(row["pm_obj"]) : "N/A"
                uc_obj_str = uc_solved ? _fmt(row["uc_obj"]) : "N/A"
                gap_str = if pm_solved && uc_solved
                    _fmt(row["obj_gap_pct"], 4)
                else
                    "N/A"
                end
                line = join(
                    [
                        "| $c",
                        "$(row["buses"])",
                        pm_obj_str,
                        uc_obj_str,
                        gap_str,
                        "$(_fmt(row["pm_parse_time"], 3))",
                        "$(_fmt(row["uc_read_time"], 3))",
                        "$(_fmt(row["pm_build_time"], 3))",
                        "$(_fmt(row["uc_build_time"], 3))",
                        "$(_fmt(row["pm_optimize_time"], 3))",
                        "$(_fmt(row["uc_optimize_time"], 3))",
                        "$(row["pm_vars"])",
                        "$(row["uc_vars"])",
                        "$(row["pm_constrs"])",
                        "$(row["uc_constrs"]) |",
                    ],
                    " | ",
                )
                println(f, line)
            end
        end
        println("Wrote: $path")
    end
    return nothing
end

function _write_json_results(path, results)
    open(path, "w") do f
        JSON.print(f, results, 2)
        println(f)
    end
    println("Wrote: $path")
    return nothing
end

# ── Main ───────────────────────────────────────────────────────────────

function main()
    cases = copy(CASES)
    for i in 1:length(ARGS)
        if ARGS[i] == "--cases" && i < length(ARGS)
            pattern = Regex(ARGS[i+1])
            cases = filter(c -> occursin(pattern, c), CASES)
        end
    end

    if isempty(cases)
        println("No cases match the filter.")
        return nothing
    end
    println("Cases: $(join(cases, ", "))")

    formulations = _make_formulations()

    _ensure_pglib()
    _convert_cases(cases)
    _warmup(cases, formulations)

    results = _run_benchmarks(cases, formulations)

    mkpath(RESULTS_DIR)
    _write_csv(joinpath(RESULTS_DIR, "benchmark.csv"), results)
    _write_markdown_tables(RESULTS_DIR, results)
    _write_json_results(
        joinpath(RESULTS_DIR, "benchmark.json"),
        results,
    )

    println("\n=== Done ===")
    println("Results written to: $RESULTS_DIR")
    return nothing
end

main()
