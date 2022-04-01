# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using Distributed
using Random

function _run_benchmark_sample(;
    case::String,
    method::SolutionMethod,
    formulation::Formulation,
    solution_filename::String,
    optimizer,
)::Nothing
    total_time = @elapsed begin
        @info "Reading: $case"
        time_read = @elapsed begin
            instance = read_benchmark(case)
        end
        @info @sprintf("Read problem in %.2f seconds", time_read)
        BLAS.set_num_threads(Threads.nthreads())
        model = build_model(
            instance = instance,
            formulation = formulation,
            optimizer = optimizer,
            variable_names = true,
        )
        @info "Optimizing..."
        BLAS.set_num_threads(1)
        optimize!(model, method)
    end
    @info @sprintf("Total time was %.2f seconds", total_time)

    @info "Writing solution: $solution_filename"
    solution = UnitCommitment.solution(model)
    write("$solution_filename", solution)

    @info "Verifying solution..."
    validate(instance, solution)
    return
end

function _run_benchmark_combination(
    case::String,
    optimizer_name::String,
    optimizer,
    method_name::String,
    method::SolutionMethod,
    formulation_name::String,
    formulation::Formulation,
    trial,
)
    dirname = "results/$optimizer_name/$method_name/$formulation_name/$case"
    function info(msg)
        @info @sprintf(
            "%-8s %-16s %-16s %-16s %-8s %s",
            msg,
            optimizer_name,
            method_name,
            formulation_name,
            trial,
            case
        )
    end
    mkpath(dirname)
    trial_filename = @sprintf("%s/%03d.json", dirname, trial)
    if isfile(trial_filename)
        info("skip")
        return
    end
    info("run")
    open("$trial_filename.log", "w") do file
        redirect_stdout(file) do
            redirect_stderr(file) do
                return _run_benchmark_sample(
                    case = case,
                    method = method,
                    formulation = formulation,
                    solution_filename = trial_filename,
                    optimizer = optimizer,
                )
            end
        end
    end
    return info("done")
end

function _run_benchmarks(;
    cases::Vector{String},
    optimizers::Dict,
    formulations::Dict,
    methods::Dict,
    trials,
)
    combinations = [
        (c, s.first, s.second, m.first, m.second, f.first, f.second, t) for c in cases
        for s in optimizers for f in formulations for m in methods for t in trials
    ]
    shuffle!(combinations)
    if nworkers() > 1
        @printf("%24s", "")
    end
    @info @sprintf(
        "%-8s %-16s %-16s %-16s %-8s %s",
        "STATUS",
        "SOLVER",
        "METHOD",
        "FORMULATION",
        "TRIAL",
        "CASE"
    )
    @sync @distributed for c in combinations
        _run_benchmark_combination(c...)
    end
end
