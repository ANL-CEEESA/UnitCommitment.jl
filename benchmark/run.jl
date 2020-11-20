# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using UnitCommitment
using JuMP
using Gurobi
using JSON
using Logging
using Printf
using LinearAlgebra

function main()
    NUM_THREADS = 4
    time_limit = 60 * 20
    BLAS.set_num_threads(NUM_THREADS)

    if length(ARGS) >= 2
      mode = string("_", ARGS[2])
    else
      mode = "_default"
    end
    if length(ARGS) >= 3 && !isempty(strip(ARGS[3]))
      results_dir = ARGS[3]
    else
      results_dir = string("./","results$mode")
    end

    # Validate mode and set formulation
    if mode == "_default"
      formulation = UnitCommitment.DefaultFormulation
    elseif mode == "_tight"
      formulation = UnitCommitment.TightFormulation
    elseif mode == "_sparse"
      formulation = UnitCommitment.SparseDefaultFormulation
    else
      error("Unknown formulation requested: ", ARGS[2])
    end

    # Filename is instance_name.sample_number.sol.gz
    # Parse out the instance + sample parts to create output files
    basename, suffix = split(ARGS[1], ".") # will not work if suffix part is not present
    model_filename_stub = string(results_dir,"/$basename.$suffix")
    solution_filename = string("$model_filename_stub.sol.json")

    # Choose logging options
    logname, logfile = nothing, nothing
    #logname = string("$model_filename_stub.out")
    if isa(logname, String) && !isempty(logname)
      logfile = open(logname, "w")
      global_logger(TimeLogger(initial_time = time(), file = logfile))
    else
      global_logger(TimeLogger(initial_time = time()))
    end

    total_time = @elapsed begin
        @info "Reading: $basename"
        time_read = @elapsed begin
            instance = UnitCommitment.read_benchmark(basename)
        end
        @info @sprintf("Read problem in %.2f seconds", time_read)

        time_model = @elapsed begin
            optimizer=optimizer_with_attributes(Gurobi.Optimizer,
                                                "Threads" => NUM_THREADS,
                                                "Seed" => rand(1:1000))
            model = build_model(instance=instance, optimizer=optimizer, formulation=formulation)
        end
    end

    @info "Setting names..."
    UnitCommitment.set_variable_names!(model)

    model_filename = string(model_filename_stub,".init",".mps.gz")
    @info string("Exporting initial model without transmission constraints to ", model_filename)
    JuMP.write_to_file(model.mip, model_filename)

    total_time += @elapsed begin
        @info "Optimizing..."
        BLAS.set_num_threads(1)
        UnitCommitment.optimize!(model, time_limit=time_limit, gap_limit=1e-3)
    end

    @info @sprintf("Total time was %.2f seconds", total_time)

    @info "Writing: $solution_filename"
    solution = UnitCommitment.get_solution(model)
    open(solution_filename, "w") do file
        JSON.print(file, solution, 2)
    end

    @info "Verifying solution..."
    UnitCommitment.validate(instance, solution) 

    model_filename = string(model_filename_stub,".final",".mps.gz")
    @info string("Exporting final model to ", model_filename)
    JuMP.write_to_file(model.mip, model_filename)

    if !isnothing(logfile)
      close(logfile)
    end
end # main

main()
