using Base: Order
using DataStructures
using DataFrames, DelimitedFiles, Statistics
using MPI, Printf
using Glob, Gurobi, JuMP
const TEMPDIR = tempdir()
const INPUT_PATH = "$(TEMPDIR)/input_files/new_scenarios"
const FILENAME = "$(abspath(joinpath(pathof(UnitCommitment), "..")))solution/methods/ProgressiveHedging/ph_subp.jl"

function _scenario_to_dict(
    sc::UnitCommitment.UnitCommitmentScenario,
)::OrderedDict
    json = OrderedDict()
    json["Parameters"] = OrderedDict()
    json["Parameters"]["Scenario name"] = sc.name
    json["Parameters"]["Scenario weight"] = sc.probability
    json["Parameters"]["Version"] = "0.3"
    json["Parameters"]["Time (h)"] = sc.time
    json["Parameters"]["Power balance penalty (\$/MW)"] =
        sc.power_balance_penalty
    if length(sc.reserves) > 0
        json["Reserves"] = OrderedDict()
        for r in sc.reserves
            r_dict = json["Reserves"][r.name] = OrderedDict()
            r_dict["Type"] = r.type
            r_dict["Amount (MW)"] = r.amount
            r_dict["Shortfall penalty (\$/MW)"] = r.shortfall_penalty
        end
    end
    json["Buses"] = OrderedDict()
    total_load = sum([b.load for b in sc.buses])
    json["Buses"]["b1"] = OrderedDict()
    json["Buses"]["b1"]["Load (MW)"] = total_load
    json["Generators"] = OrderedDict()
    for g in sc.thermal_units
        g_dict = json["Generators"][g.name] = OrderedDict()
        g_dict["Bus"] = "b1"
        g_dict["Ramp up limit (MW)"] = g.ramp_up_limit
        g_dict["Ramp down limit (MW)"] = g.ramp_down_limit
        g_dict["Startup limit (MW)"] = g.startup_limit
        g_dict["Shutdown limit (MW)"] = g.shutdown_limit
        g_dict["Minimum uptime (h)"] = g.min_uptime
        g_dict["Minimum downtime (h)"] = g.min_downtime
        g_dict["Initial status (h)"] = g.initial_status
        g_dict["Initial power (MW)"] = g.initial_power
        g_dict["Must run?"] = g.must_run
        g_dict["Startup delays (h)"] =
            [st_c.delay for st_c in g.startup_categories]
        g_dict["Startup costs (\$)"] =
            [st_c.cost for st_c in g.startup_categories]
        K = length(g.cost_segments) + 1
        T = length(g.min_power)
        curve_mw = Matrix{Float64}(undef, T, K)
        curve_cost = Matrix{Float64}(undef, T, K)
        curve_mw[:, 1] = g.min_power
        curve_cost[:, 1] = g.min_power_cost
        for k in 1:K-1
            curve_mw[:, k+1] = curve_mw[:, k] + g.cost_segments[k].mw
            curve_cost[:, k+1] =
                curve_cost[:, k] +
                (g.cost_segments[k].cost .* g.cost_segments[k].mw)
        end
        g_dict["Production cost curve (MW)"] = (curve_mw)
        g_dict["Production cost curve (\$)"] = (curve_cost)
        length(g.reserves) == 0 ||
            (g_dict["Reserve eligibility"] = [r.name for r in g.reserves])
    end
    return json
end
function _create_new_scenarios(
    s_num::Int,
    r::Int,
    system::String,
    date::String,
)::String
    path = "$(INPUT_PATH)/$(system)/snum_$(s_num)/run_$r"
    benchmark = "matpower/$(system)/$(date)"
    mkpath(path)
    for sn in 1:s_num
        sc = UnitCommitment.read_benchmark(benchmark).scenarios[1]
        randomize!(sc, UnitCommitment.XavQiuAhm2021.Randomization())
        sc.name = "s$(sn)"
        sc.probability = 1 / s_num
        sc_dict = _scenario_to_dict(sc)
        write("$(path)/s$(sn).json", sc_dict)
    end
    return path
end
function _solve_instance(scenarios::Vector{String})::AbstractDict
    instance = UnitCommitment.read(scenarios)
    model = UnitCommitment.build_model(
        instance = instance,
        optimizer = Gurobi.Optimizer,
        formulation = Formulation(),
    )
    set_optimizer_attribute(model, "Threads", length(instance.scenarios))
    time_stat = @timed UnitCommitment.optimize!(model)
    extensive_solution = Dict(
        "objective value" => objective_value(model),
        "binary values" =>
            [value(var) for var in all_variables(model) if is_binary(var)],
        "solution statistics" => time_stat,
    )
    return extensive_solution
end
function _write_setup(system::String, snum::Int, r::Int)
    open("$(INPUT_PATH)/setup.txt", "w") do file
        return Base.write(file, @sprintf("%s,%d,%d", system, snum, r))
    end
end
function _retrieve_results(
    extensive_solution::Dict,
    solution_path::String,
)::OrderedDict
    result = OrderedDict()
    result["extensive form"] = OrderedDict()
    result["extensive form"]["objective value"] =
        extensive_solution["objective value"]
    result["extensive form"]["wallclock time"] =
        extensive_solution["solution statistics"].time
    result["progressive hedging"] = OrderedDict()
    open("$(solution_path)/1/global_obj.txt") do glob_obj
        return global global_obj = split(Base.read(glob_obj, String))[1]
    end
    open("$(solution_path)/1/wallclock_time.txt") do wallcl_time
        return global wallclock_time = split(Base.read(wallcl_time, String))[1]
    end
    result["progressive hedging"]["objective value"] =
        parse(Float64, global_obj)
    result["progressive hedging"]["wallclock time"] =
        parse(Float64, wallclock_time)
    extensive_binary_vals = extensive_solution["binary values"]
    ph_binary_vals =
        vec(readdlm("$(solution_path)/1/binary_vals.csv", ',', Float64))
    result["% similarity"] =
        (
            1 - (
                sum(abs.(extensive_binary_vals - ph_binary_vals)) /
                length(extensive_binary_vals)
            )
        ) * 100
    return result
end
function fetch_ph_benchmark_summary_df(
    solution_stat::OrderedDict,
)::AbstractDataFrame
    extensive_obj = Vector{Float64}(undef, 0)
    ph_obj = Vector{Float64}(undef, 0)
    extensive_time = Vector{Float64}(undef, 0)
    ph_time = Vector{Float64}(undef, 0)
    setup = Vector{String}(undef, 0)
    similarity = Vector{Float64}(undef, 0)
    for (system, system_result) in solution_stat
        for (snum, snum_result) in system_result
            push!(setup, @sprintf("%s (%s)", system, snum))
            push!(
                extensive_obj,
                round(
                    mean([
                        snum_result[rep]["extensive form"]["objective value"]
                        for rep in keys(snum_result)
                    ]),
                    digits = 3,
                ),
            )
            push!(
                ph_obj,
                round(
                    mean([
                        snum_result[rep]["progressive hedging"]["objective value"]
                        for rep in keys(snum_result)
                    ]),
                    digits = 3,
                ),
            )
            push!(
                extensive_time,
                round(
                    mean([
                        snum_result[rep]["extensive form"]["wallclock time"] for
                        rep in keys(snum_result)
                    ]),
                    digits = 3,
                ),
            )
            push!(
                ph_time,
                round(
                    mean([
                        snum_result[rep]["progressive hedging"]["wallclock time"]
                        for rep in keys(snum_result)
                    ]),
                    digits = 3,
                ),
            )
            push!(
                similarity,
                round(
                    mean([
                        snum_result[rep]["% similarity"] for
                        rep in keys(snum_result)
                    ]),
                    digits = 3,
                ),
            )
        end
    end
    df = DataFrame(
        hcat(setup, extensive_obj, ph_obj, extensive_time, ph_time, similarity),
        [
            "system (scenario number)",
            "objective value-extensive",
            "objective value-ph",
            "wallclock time-extensive",
            "wallclock time-ph",
            "% similarity",
        ],
    )
    return df
end
function fetch_ph_benchmark_detailed_df(
    solution_stat::OrderedDict,
)::AbstractDataFrame
    systems = Vector{String}(undef, 0)
    scenario_numbers = Vector{Int}(undef, 0)
    methods = Vector{String}(undef, 0)
    run_indices = Vector{Int}(undef, 0)
    objective_values = Vector{Float64}(undef, 0)
    wallclock_times = Vector{Float64}(undef, 0)
    similarities = Vector{Float64}(undef, 0)
    for (system, system_result) in solution_stat
        for (snum, snum_result) in system_result
            for (run, run_result) in snum_result
                for method in ["extensive form", "progressive hedging"]
                    push!(systems, system)
                    push!(scenario_numbers, snum)
                    push!(methods, method)
                    push!(run_indices, run)
                    push!(
                        objective_values,
                        round(
                            run_result[method]["objective value"],
                            digits = 3,
                        ),
                    )
                    push!(
                        wallclock_times,
                        round(run_result[method]["wallclock time"], digits = 3),
                    )
                    push!(
                        similarities,
                        round(run_result["% similarity"], digits = 3),
                    )
                end
            end
        end
    end
    df = DataFrame(
        hcat(
            systems,
            scenario_numbers,
            methods,
            run_indices,
            objective_values,
            wallclock_times,
            similarities,
        ),
        [
            "system",
            "number of scenarios",
            "method",
            "run-x",
            "objective value",
            "wallclock time",
            "% similarity",
        ],
    )
    return df
end
function run_ph_benchmark(
    cases::AbstractDict;
    date::String = "2017-01-01",
)::OrderedDict
    mkpath(INPUT_PATH)
    solution_stat = OrderedDict()
    for system in keys(cases)
        solution_stat[system] = OrderedDict()
        for s_num in cases[system]["scenario numbers"]
            solution_stat[system][s_num] = OrderedDict()
            for r in 1:cases[system]["number of runs"]
                solution_stat[system][s_num][r] = OrderedDict()
                scenario_path = _create_new_scenarios(s_num, r, system, date)
                solution_path = "$(TEMPDIR)/output_files/$(system)/snum_$(s_num)/run_$(r)"
                mkpath(solution_path)
                extensive_solution =
                    _solve_instance(glob("*.json", scenario_path))
                _write_setup(system, s_num, r)
                mpiexec(
                    exe -> run(`$exe -n $s_num $(Base.julia_cmd()) $FILENAME`),
                )
                result = _retrieve_results(extensive_solution, solution_path)
                solution_stat[system][s_num][r] = result
            end
        end
    end
    return solution_stat
end
