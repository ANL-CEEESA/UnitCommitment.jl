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

@everywhere import UnitCommitment:
    ArrCon2000,
    CarArr2006,
    DamKucRajAta2016,
    Formulation,
    Gar1962,
    KnuOstWat2018,
    MorLatRam2013,
    PanGua2016,
    XavQiuWanThi2019

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
        "Default" => Formulation(),
        "ArrCon2000" => Formulation(ramping = ArrCon2000.Ramping()),
        "CarArr2006" => Formulation(pwl_costs = CarArr2006.PwlCosts()),
        "DamKucRajAta2016" =>
            Formulation(ramping = DamKucRajAta2016.Ramping()),
        "Gar1962" => Formulation(pwl_costs = Gar1962.PwlCosts()),
        "KnuOstWat2018" =>
            Formulation(pwl_costs = KnuOstWat2018.PwlCosts()),
        "MorLatRam2013" => Formulation(ramping = MorLatRam2013.Ramping()),
        "PanGua2016" => Formulation(ramping = PanGua2016.Ramping()),
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
        @info @sprintf("%-4s %-16s %s", "skip", formulation_name, case)
        return
    end
    @info @sprintf("%-4s %-16s %s", "run", formulation_name, case)
    open("$dirname/$trial.log", "w") do file
        redirect_stdout(file) do
            redirect_stderr(file) do
                return _run_sample(case, formulation, "$dirname/$trial")
            end
        end
    end
    @info @sprintf("%-4s %-16s %s", "done", formulation_name, case)
end

@everywhere function _run_sample(case, formulation, prefix)
    total_time = @elapsed begin
        @info "Reading: $case"
        time_read = @elapsed begin
            instance = UnitCommitment.read_benchmark(case)
        end
        @info @sprintf("Read problem in %.2f seconds", time_read)
        BLAS.set_num_threads(4)
        model = UnitCommitment.build_model(
            instance = instance,
            formulation = formulation,
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
            XavQiuWanThi2019.Method(time_limit = 3600.0, gap_limit = 1e-4),
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
