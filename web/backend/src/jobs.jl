# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2025, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

import Base: put!

Base.@kwdef mutable struct JobProcessor
    pending::Channel{String} = Channel{String}(Inf)
    processing::Channel{String} = Channel{String}(Inf)
    shutdown::Channel{Bool} = Channel{Bool}(1)
    worker_task::Union{Task,Nothing} = nothing
    work_fn::Function
end

function Base.put!(processor::JobProcessor, job_id::String)
    @info "New job received: $job_id"
    return put!(processor.pending, job_id)
end

function isbusy(processor::JobProcessor)
    return isready(processor.pending) || isready(processor.processing)
end

function run!(processor::JobProcessor)
    while true
        # Check for shutdown signal
        if isready(processor.shutdown)
            break
        end

        # Wait for a job with timeout
        if !isready(processor.pending)
            sleep(0.1)
            continue
        end

        # Move job from pending to processing queue
        job_id = take!(processor.pending)
        put!(processor.processing, job_id)

        # Prepare directories
        job_dir = joinpath(basedir, "jobs", job_id)
        log_path = joinpath(job_dir, "output.log")
        mkpath(job_dir)

        # Run work function
        try
            @info "Processing job: $job_id"
            open(log_path, "w") do io
                redirect_stdout(io) do
                    redirect_stderr(io) do
                        processor.work_fn(job_id)
                        @info "Job $job_id done"
                    end
                end
            end

            # Remove job from processing queue
            take!(processor.processing)
        catch e
            @error "Failed job: $job_id" e
            open(log_path, "a") do io
                println(io, "\nError: ", e)
                println(io, "\nStacktrace:")
                return Base.show_backtrace(io, catch_backtrace())
            end
        end
    end
end

function start(processor::JobProcessor)
    processor.worker_task = @async run!(processor)
    return
end

function stop(processor::JobProcessor)
    # Signal worker to stop
    put!(processor.shutdown, true)

    # Wait for worker to finish
    if processor.worker_task !== nothing
        try
            wait(processor.worker_task)
        catch
            # Worker may have already exited
        end
    end
    return
end

export JobProcessor, start, stop, put!, isbusy
