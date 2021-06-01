# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using Distributed
using Pkg
Pkg.activate(".")

@everywhere using Pkg
@everywhere Pkg.activate(".")

@everywhere using UnitCommitment
@everywhere using JuMP
@everywhere using Gurobi
@everywhere using JSON
@everywhere using Logging
@everywhere using Printf
@everywhere using LinearAlgebra
@everywhere using Random

@everywhere UnitCommitment._setup_logger()

function main()
    cases = [
        "pglib-uc/ca/2014-09-01_reserves_0",
        "pglib-uc/ca/2014-09-01_reserves_1",
        "pglib-uc/ca/2015-03-01_reserves_0",
        "pglib-uc/ca/2015-06-01_reserves_0",
        "pglib-uc/ca/Scenario400_reserves_1",
        "pglib-uc/ferc/2015-01-01_lw",
        "pglib-uc/ferc/2015-05-01_lw",
        "pglib-uc/ferc/2015-07-01_hw",
        "pglib-uc/ferc/2015-10-01_lw",
        "pglib-uc/ferc/2015-12-01_lw",
        "pglib-uc/rts_gmlc/2020-04-03",
        "pglib-uc/rts_gmlc/2020-09-20",
        "pglib-uc/rts_gmlc/2020-10-27",
        "pglib-uc/rts_gmlc/2020-11-25",
        "pglib-uc/rts_gmlc/2020-12-23",
        "or-lib/20_0_1_w",
        "or-lib/20_0_5_w",
        "or-lib/50_0_2_w",
        "or-lib/75_0_2_w",
        "or-lib/100_0_1_w",
        "or-lib/100_0_4_w",
        "or-lib/100_0_5_w",
        "or-lib/200_0_3_w",
        "or-lib/200_0_7_w",
        "or-lib/200_0_9_w",
        "tejada19/UC_24h_290g",
        "tejada19/UC_24h_623g",
        "tejada19/UC_24h_959g",
        "tejada19/UC_24h_1577g",
        "tejada19/UC_24h_1888g",
        "tejada19/UC_168h_72g",
        "tejada19/UC_168h_86g",
        "tejada19/UC_168h_130g",
        "tejada19/UC_168h_131g",
        "tejada19/UC_168h_199g",
    ]
    formulations = Dict(
        "ArrCon00" =>
            UnitCommitment.Formulation(ramping = UnitCommitment.ArrCon00()),
        "DamKucRajAta16" => UnitCommitment.Formulation(
            ramping = UnitCommitment.DamKucRajAta16(),
        ),
        "MorLatRam13" => UnitCommitment.Formulation(
            ramping = UnitCommitment.MorLatRam13(),
        ),
        "PanGua16" => UnitCommitment.Formulation(
            ramping = UnitCommitment.PanGua16(),
        ),
    )
    trials = [i for i in 1:5]
    combinations = [
        (c, f.first, f.second, t) for c in cases for f in formulations for
        t in trials
    ]
    shuffle!(combinations)
    @sync @distributed for c in combinations
        _run_combination(c...)
    end
end

@everywhere function _run_combination(
    case,
    formulation_name,
    formulation,
    trial,
)
    name = "$formulation_name/$case"
    dirname = "results/$name"
    mkpath(dirname)
    if isfile("$dirname/$trial.json")
        @info @sprintf(
            "%-8s %-20s %-40s",
            "skip",
            formulation_name,
            "$case/$trial",
        )
        return
    end
    @info @sprintf(
        "%-8s %-20s %-40s",
        "start",
        formulation_name,
        "$case/$trial",
    )
    time = @elapsed open("$dirname/$trial.log", "w") do file
        redirect_stdout(file) do
            redirect_stderr(file) do
                return _run_sample(case, formulation, "$dirname/$trial")
            end
        end
    end
    @info @sprintf(
        "%-8s %-20s %-40s %12.3f",
        "finish",
        formulation_name,
        "$case/$trial",
        time
    )
end

@everywhere function _run_sample(case, formulation, prefix)
    total_time = @elapsed begin
        @info "Reading: $case"
        time_read = @elapsed begin
            instance = UnitCommitment.read_benchmark(case)
        end
        @info @sprintf("Read problem in %.2f seconds", time_read)
        BLAS.set_num_threads(4)
        model = UnitCommitment._build_model(
            instance,
            formulation,
            optimizer = optimizer_with_attributes(
                Gurobi.Optimizer,
                "Threads" => 4,
                "Seed" => rand(1:1000),
            ),
            variable_names = true,
        )
        @info "Optimizing..."
        BLAS.set_num_threads(1)
        UnitCommitment.optimize!(
            model,
            UnitCommitment.XavQiuWanThi19(
                time_limit = 3600.0,
                gap_limit = 1e-4,
            ),
        )
    end
    @info @sprintf("Total time was %.2f seconds", total_time)
    @info "Writing solution: $prefix.json"
    solution = UnitCommitment.solution(model)
    UnitCommitment.write("$prefix.json", solution)
    @info "Verifying solution..."
    return UnitCommitment.validate(instance, solution)
    # @info "Exporting model..."
    # return JuMP.write_to_file(model, model_filename)
end

if length(ARGS) > 0
    _run_sample(ARGS[1], UnitCommitment.Formulation(), "tmp")
else
    main()
end
