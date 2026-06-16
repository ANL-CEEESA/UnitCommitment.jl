#!/usr/bin/env julia
#
# Converts a MATPOWER .m file into a single-period UnitCommitment.jl 0.5 JSON
# test case and solves various OPF problems.
#
# Usage:
#   julia --project scripts/matpower_to_ucjl.jl input.m output_dir/
#
# Requires PowerModels.jl, JSON.jl, DataStructures.jl, Ipopt.jl,
# HiGHS.jl, and Juniper.jl in the active project environment.

using PowerModels
using JSON
using DataStructures: OrderedDict
using Ipopt
using HiGHS
using Juniper
using JuMP

function matpower_to_ucjl(
    input_file::String,
    output_dir::String;
    time_horizon_h::Int = 1,
    time_step_min::Int = 60,
    num_cost_segments::Int = 3,
    power_balance_penalty::Float64 = 1000.0,
    flow_limit_penalty::Float64 = 5000.0,
    relax_angle_diffs::Bool = false,
)
    mkpath(output_dir)

    # --- Copy original .m file ---
    dst = joinpath(output_dir, "original.m")
    if abspath(input_file) != abspath(dst)
        cp(input_file, dst; force = true)
        println("Saved: $dst")
    end

    # --- Build and save converted.json ---
    data = PowerModels.parse_file(input_file)
    if relax_angle_diffs
        _relax_angle_diffs!(data)
    end
    if data["per_unit"]
        PowerModels.make_mixed_units!(data)
    end
    result = _build_ucjl_json(
        data,
        time_horizon_h,
        time_step_min,
        num_cost_segments,
        power_balance_penalty,
        flow_limit_penalty,
    )
    _write_json(joinpath(output_dir, "converted.json"), result)

    # --- Solve OPF/PF problems and save solutions ---
    _solve_and_save(
        input_file,
        output_dir;
        relax_angle_diffs = relax_angle_diffs,
        num_cost_segments = num_cost_segments,
    )
end

function _solve_and_save(
    input_file::String,
    output_dir::String;
    relax_angle_diffs::Bool = false,
    num_cost_segments::Int = 0,
)
    t_parse = @elapsed begin
        data = PowerModels.parse_file(input_file)
    end
    if relax_angle_diffs
        _relax_angle_diffs!(data)
    end
    if num_cost_segments > 0
        _convert_costs_to_pwl!(data; num_segments = num_cost_segments)
    end


    ipopt_silent =
        optimizer_with_attributes(Ipopt.Optimizer, "print_level" => 0)
    highs_silent =
        optimizer_with_attributes(HiGHS.Optimizer, "output_flag" => false)
    juniper = optimizer_with_attributes(
        Juniper.Optimizer,
        "nl_solver" => ipopt_silent,
        "mip_solver" => highs_silent,
        "log_levels" => [],
    )

    has_strg = haskey(data, "storage") && !isempty(data["storage"])

    # Use storage-aware multi-network OPF when storage is present
    # (requires MINLP solver due to binary storage complementarity
    # variables). Stats collection is not supported for this path.
    if has_strg
        mn_data = PowerModels.replicate(data, 1)
        problems = [
            (
                "sol_ac_opf.json",
                "AC OPF",
                () -> solve_mn_opf_strg(
                    mn_data,
                    ACPPowerModel,
                    juniper,
                ),
            ),
            (
                "sol_dc_opf.json",
                "DC OPF",
                () -> solve_mn_opf_strg(
                    mn_data,
                    DCPPowerModel,
                    highs_silent,
                ),
            ),
            (
                "sol_soc_opf.json",
                "SOC OPF",
                () -> solve_mn_opf_strg(
                    mn_data,
                    SOCWRPowerModel,
                    juniper,
                ),
            ),
        ]
        for (filename, label, solve_fn) in problems
            path = joinpath(output_dir, filename)
            try
                sol = solve_fn()
                _save_solution(path, sol)
                status = sol["termination_status"]
                obj = get(sol, "objective", nothing)
                println("  $label: $status, obj=$obj")
            catch e
                @warn "Failed: $label" exception =
                    (e, catch_backtrace())
            end
        end
        return nothing
    end

    # Non-storage cases: timed pipeline with stats
    problems = [
        ("sol_ac_opf.json", "AC OPF", ACPPowerModel, :ipopt, PowerModels.build_opf),
        ("sol_dc_opf.json", "DC OPF", DCPPowerModel, :highs, PowerModels.build_opf),
        ("sol_soc_opf.json", "SOC OPF", SOCWRPowerModel, :ipopt, PowerModels.build_opf),
        ("sol_ac_pf.json", "AC PF", ACPPowerModel, :ipopt, PowerModels.build_pf),
        ("sol_dc_pf.json", "DC PF", DCPPowerModel, :highs, PowerModels.build_pf),
    ]
    for (filename, label, model_type, solver_key, build_fn) in problems
        path = joinpath(output_dir, filename)
        log_file = joinpath(
            output_dir,
            replace(filename, ".json" => ".log"),
        )
        solver = if solver_key == :ipopt
            optimizer_with_attributes(
                Ipopt.Optimizer,
                "print_level" => 5,
                "output_file" => log_file,
            )
        else
            optimizer_with_attributes(
                HiGHS.Optimizer,
                "output_flag" => true,
                "log_file" => log_file,
            )
        end
        model_file = joinpath(
            output_dir,
            replace(filename, ".json" => ".mof.json"),
        )
        try
            t_build = @elapsed begin
                pm = PowerModels.instantiate_model(
                    data,
                    model_type,
                    build_fn,
                )
            end
            n_vars = JuMP.num_variables(pm.model)
            n_constrs = _count_constraints(pm.model)
            JuMP.write_to_file(pm.model, model_file)
            println("  Saved model: $model_file")
            t_optimize = @elapsed begin
                sol = PowerModels.optimize_model!(
                    pm;
                    optimizer = solver,
                )
            end
            stats = OrderedDict{String,Any}(
                "parse_time" => round(t_parse; digits = 6),
                "build_time" => round(t_build; digits = 6),
                "optimize_time" => round(t_optimize; digits = 6),
                "num_variables" => n_vars,
                "num_constraints" => n_constrs,
            )
            _save_solution(path, sol; stats = stats)
            status = sol["termination_status"]
            obj = get(sol, "objective", nothing)
            println("  $label: $status, obj=$obj")
        catch e
            @warn "Failed: $label" exception =
                (e, catch_backtrace())
        end
    end
    return nothing
end

function _save_solution(
    path::String,
    sol::Dict;
    stats::Union{Nothing,OrderedDict} = nothing,
)
    out = OrderedDict{String,Any}(
        "termination_status" => string(sol["termination_status"]),
        "objective" => get(sol, "objective", nothing),
        "solution" => get(sol, "solution", Dict()),
    )
    if stats !== nothing
        out["stats"] = stats
    end
    _write_json(path, out)
    return nothing
end

function _write_json(path::String, data)
    open(path, "w") do f
        JSON.print(f, data, 2)
        println(f)
    end
    println("Saved: $path")
end

function _count_constraints(m::JuMP.Model)
    return sum(
        JuMP.num_constraints(m, F, S)
        for (F, S) in JuMP.list_of_constraint_types(m);
        init = 0,
    )
end

function _relax_angle_diffs!(data::Dict)
    for (_, branch) in data["branch"]
        branch["angmin"] = -Inf
        branch["angmax"] = Inf
    end
    return nothing
end

function _convert_costs_to_pwl!(data::Dict; num_segments::Int = 3)
    for (_, gen) in data["gen"]
        model = get(gen, "model", 2)
        model == 1 && continue
        cost = get(gen, "cost", Float64[])
        isempty(cost) && continue

        pmin = max(gen["pmin"], 0.0)
        pmax = gen["pmax"]
        pmax <= pmin && continue

        coeffs = reverse(cost)
        eval_poly(p) =
            sum(coeffs[i] * p^(i - 1) for i in eachindex(coeffs))

        n_points = num_segments + 1
        points = collect(range(pmin, pmax; length = n_points))
        pwl = Float64[]
        for p in points
            push!(pwl, p)
            push!(pwl, eval_poly(p))
        end

        gen["model"] = 1
        gen["ncost"] = n_points
        gen["cost"] = pwl
    end
    return nothing
end

function _build_ucjl_json(
    data::Dict,
    time_horizon_h::Int,
    time_step_min::Int,
    num_cost_segments::Int,
    power_balance_penalty::Float64,
    flow_limit_penalty::Float64,
)
    baseMVA = data["baseMVA"]
    result = OrderedDict{String, Any}()

    # --- Parameters ---
    result["Parameters"] = OrderedDict{String, Any}(
        "Version" => "0.5",
        "Base MVA" => baseMVA,
        "Time horizon (h)" => time_horizon_h,
        "Time step (min)" => time_step_min,
        "Power balance penalty (\$/MW)" => power_balance_penalty,
    )

    # --- Buses ---
    # Aggregate loads per bus (multiple loads can be at the same bus)
    bus_pd = Dict{Int, Float64}()
    bus_qd = Dict{Int, Float64}()
    for (_, load) in data["load"]
        load["status"] == 0 && continue
        b = load["load_bus"]
        bus_pd[b] = get(bus_pd, b, 0.0) + load["pd"]
        bus_qd[b] = get(bus_qd, b, 0.0) + load["qd"]
    end

    bus_type_map = Dict(1 => "PQ", 2 => "PV", 3 => "Slack")
    buses = OrderedDict{String, Any}()
    for bus_id in sort(collect(keys(data["bus"])); by = x -> parse(Int, x))
        bus = data["bus"][bus_id]
        bus["bus_type"] == 4 && continue
        bi = bus["bus_i"]
        bus_data = OrderedDict{String, Any}(
            "Load (MW)" => get(bus_pd, bi, 0.0),
        )
        qd = get(bus_qd, bi, 0.0)
        if qd != 0.0
            bus_data["Load (MVAr)"] = qd
        end
        bus_data["Minimum voltage (p.u.)"] = bus["vmin"]
        bus_data["Maximum voltage (p.u.)"] = bus["vmax"]
        bus_data["Bus type"] = bus_type_map[bus["bus_type"]]
        buses["b$bus_id"] = bus_data
    end
    result["Buses"] = buses

    # --- Generators (all treated as Thermal) ---
    generators = OrderedDict{String, Any}()
    for gen_id in sort(collect(keys(data["gen"])); by = x -> parse(Int, x))
        gen = data["gen"][gen_id]
        gen["gen_status"] == 0 && continue

        bus_id = gen["gen_bus"]
        pmin = max(gen["pmin"], 0.0)
        pmax = gen["pmax"]

        # Skip generators with no active or reactive capability.
        # Keep synchronous condensers (pmax=0 but qmin/qmax != 0)
        # since they provide reactive power for AC power flow.
        has_reactive = gen["qmin"] != 0.0 || gen["qmax"] != 0.0
        pmax <= 0 && !has_reactive && continue
        pmax = max(pmax, 0.0)

        # Build production cost curve
        mw_points, cost_points = _build_cost_curve(gen, pmin, pmax, num_cost_segments)

        gen_data = OrderedDict{String, Any}(
            "Bus" => "b$bus_id",
            "Type" => "Thermal",
            "Production cost curve (MW)" => mw_points,
            "Production cost curve (\$)" => cost_points,
        )

        # Startup costs
        startup_cost = get(gen, "startup", 0.0)
        if startup_cost > 0
            gen_data["Startup costs (\$)"] = [startup_cost]
            gen_data["Startup delays (h)"] = [1]
        end

        # Ramp rates (use ramp_30 if available)
        ramp = get(gen, "ramp_30", 0.0)
        if ramp > 0
            gen_data["Ramp up limit (MW)"] = ramp
            gen_data["Ramp down limit (MW)"] = ramp
            gen_data["Startup limit (MW)"] = ramp
            gen_data["Shutdown limit (MW)"] = ramp
        end

        # Initial status and power
        gen_data["Initial status (h)"] = 24
        gen_data["Initial power (MW)"] = clamp(gen["pg"], pmin, pmax)

        # Reactive power limits
        gen_data["Minimum reactive power (MVAr)"] = gen["qmin"]
        gen_data["Maximum reactive power (MVAr)"] = gen["qmax"]

        gen_data["Must run?"] = [true]

        generators["g$gen_id"] = gen_data
    end
    result["Generators"] = generators

    # --- Branches ---
    branches = OrderedDict{String, Any}()
    for br_id in sort(collect(keys(data["branch"])); by = x -> parse(Int, x))
        branch = data["branch"][br_id]
        branch["br_status"] == 0 && continue

        branch_data = OrderedDict{String, Any}(
            "Source bus" => "b$(branch["f_bus"])",
            "Target bus" => "b$(branch["t_bus"])",
            "Reactance (p.u.)" => branch["br_x"],
        )

        if branch["br_r"] != 0.0
            branch_data["Resistance (p.u.)"] = branch["br_r"]
        end

        # Total line-charging shunt susceptance (b_fr + b_to)
        b_total = get(branch, "b_fr", 0.0) + get(branch, "b_to", 0.0)
        if b_total != 0.0
            branch_data["Shunt susceptance (p.u.)"] = b_total
        end

        # Total shunt conductance (usually zero)
        g_total = get(branch, "g_fr", 0.0) + get(branch, "g_to", 0.0)
        if g_total != 0.0
            branch_data["Shunt conductance (p.u.)"] = g_total
        end

        # Transformer data
        if branch["transformer"]
            branch_data["Tap ratio (p.u.)"] = branch["tap"]
            branch_data["Phase shift (rad)"] = deg2rad(branch["shift"])
        end

        # Flow limits (rate_a = long-term, rate_c = emergency)
        if haskey(branch, "rate_a") && branch["rate_a"] > 0
            branch_data["Normal flow limit (MVA)"] = branch["rate_a"]
        end
        if haskey(branch, "rate_c") && branch["rate_c"] > 0
            branch_data["Emergency flow limit (MVA)"] = branch["rate_c"]
        end

        # Angle difference limits (make_mixed_units! converts to degrees)
        # Skip infinite values; UC.jl defaults to ±Inf when absent.
        angmin = deg2rad(branch["angmin"])
        angmax = deg2rad(branch["angmax"])
        if isfinite(angmin)
            branch_data["Angle difference min (rad)"] = angmin
        end
        if isfinite(angmax)
            branch_data["Angle difference max (rad)"] = angmax
        end

        if flow_limit_penalty < 0
            branch_data["Flow limit penalty (\$/MW)"] = flow_limit_penalty
        end

        branches["l$br_id"] = branch_data
    end
    result["Branches"] = branches

    # --- Shunt devices ---
    shunts = OrderedDict{String, Any}()
    for sh_id in sort(collect(keys(data["shunt"])); by = x -> parse(Int, x))
        shunt = data["shunt"][sh_id]
        shunt["status"] == 0 && continue
        shunt_data = OrderedDict{String, Any}(
            "Bus" => "b$(shunt["shunt_bus"])",
            "Susceptance (p.u.)" => shunt["bs"] / baseMVA,
        )
        gs = shunt["gs"] / baseMVA
        if gs != 0.0
            shunt_data["Conductance (p.u.)"] = gs
        end
        shunts["sh$sh_id"] = shunt_data
    end
    if !isempty(shunts)
        result["Shunt devices"] = shunts
    end

    # --- Storage units ---
    if haskey(data, "storage") && !isempty(data["storage"])
        storage_units = OrderedDict{String, Any}()
        for st_id in sort(collect(keys(data["storage"])); by = x -> parse(Int, x))
            st = data["storage"][st_id]
            get(st, "status", 0) == 0 && continue
            st_data = OrderedDict{String, Any}(
                "Bus" => "b$(st["storage_bus"])",
                "Maximum level (MWh)" => st["energy_rating"],
                "Charge cost (\$/MW)" => 0.0,
                "Discharge cost (\$/MW)" => 0.0,
                "Maximum charge rate (MW)" => st["charge_rating"],
                "Maximum discharge rate (MW)" => st["discharge_rating"],
                "Charge efficiency" => st["charge_efficiency"],
                "Discharge efficiency" => st["discharge_efficiency"],
                "Initial level (MWh)" => st["energy"],
            )
            if haskey(st, "qmin")
                st_data["Minimum reactive power (MVAr)"] = st["qmin"]
            end
            if haskey(st, "qmax")
                st_data["Maximum reactive power (MVAr)"] = st["qmax"]
            end
            if haskey(st, "thermal_rating") && st["thermal_rating"] > 0
                st_data["Apparent power limit (MVA)"] = st["thermal_rating"]
            end
            storage_units["su$st_id"] = st_data
        end
        if !isempty(storage_units)
            result["Storage units"] = storage_units
        end
    end

    # --- DC lines (warn and skip) ---
    if haskey(data, "dcline") && !isempty(data["dcline"])
        n = length(data["dcline"])
        @warn "Skipping $n DC line(s); DC lines have no direct UC.jl equivalent."
    end

    n_buses = length(buses)
    n_gens = length(generators)
    n_lines = length(branches)
    n_shunts = length(shunts)
    println("Converted: $n_buses buses, $n_gens generators, " *
            "$n_lines lines, $n_shunts shunts")

    return result
end

"""
Build a piecewise-linear production cost curve from PowerModels generator data.
"""
function _build_cost_curve(gen, pmin, pmax, num_segments)
    model = get(gen, "model", 2)
    cost = get(gen, "cost", Float64[])

    if model == 1
        # Piecewise linear: cost = [P1, F1, P2, F2, ..., Pn, Fn]
        ncost = gen["ncost"]
        mw_points = [cost[2i - 1] for i in 1:ncost]
        cost_points = [cost[2i] for i in 1:ncost]
        return mw_points, cost_points
    end

    # Polynomial: cost = [c_{n-1}, ..., c_1, c_0] (highest to lowest degree)
    # Reverse to get [c_0, c_1, ..., c_{n-1}]
    coeffs = reverse(cost)

    eval_poly(p) = sum(coeffs[i] * p^(i - 1) for i in eachindex(coeffs))

    if isempty(coeffs)
        # No cost data; use zero cost
        return [pmin, pmax], [0.0, 0.0]
    end

    if pmin ≈ pmax
        return [pmin], [eval_poly(pmin)]
    end

    n_points = num_segments + 1
    mw_points = collect(range(pmin, pmax; length = n_points))
    cost_points = [eval_poly(p) for p in mw_points]
    return mw_points, cost_points
end

# --- Main ---
if abspath(PROGRAM_FILE) == @__FILE__
    if length(ARGS) < 2
        println(stderr, "Usage: julia matpower_to_ucjl.jl <input.m> <output_dir>")
        exit(1)
    end
    matpower_to_ucjl(ARGS[1], ARGS[2])
end
