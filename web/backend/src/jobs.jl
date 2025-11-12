# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2025, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using Distributed
import Base: put!

Base.@kwdef mutable struct JobProcessor
    pending = RemoteChannel(() -> Channel{String}(Inf))
    processing = RemoteChannel(() -> Channel{String}(Inf))
    shutdown = RemoteChannel(() -> Channel{Bool}(1))
    worker_pids = []
    worker_tasks = []
    work_fn = nothing
end

function Base.put!(processor::JobProcessor, job_id::String)
    return put!(processor.pending, job_id)
end

function isbusy(processor::JobProcessor)
    return isready(processor.pending) || isready(processor.processing)
end

function worker_loop(pending, processing, shutdown, work_fn)
    @info "Starting worker loop"
    while true
        # Check for shutdown signal
        if isready(shutdown)
            @info "Shutdown signal received"
            break
        end

        # Wait for a job with timeout
        if !isready(pending)
            sleep(0.1)
            continue
        end

        # Move job from pending to processing queue
        job_id = take!(pending)
        put!(processing, job_id)
        @info "Job started: $job_id"

        # Run work function
        try
            work_fn(job_id)
        catch e
            @error "Job failed: job $job_id"
        end

        # Remove job from processing queue
        take!(processing)
        @info "Job finished: $job_id"
    end
end

function start(processor::JobProcessor)
    # Get list of available worker processes
    worker_pids = workers()
    @info "Starting job processor with $(length(worker_pids)) worker(s)"

    # Start a worker loop on each worker process
    for pid in worker_pids
        task = @spawnat pid begin
            worker_loop(
                processor.pending,
                processor.processing,
                processor.shutdown,
                processor.work_fn,
            )
        end
        push!(processor.worker_pids, pid)
        push!(processor.worker_tasks, task)
    end
    return
end

function stop(processor::JobProcessor)
    # Send shutdown signal (all workers will see it)
    put!(processor.shutdown, true)

    # Wait for all worker tasks to complete
    for (i, task) in enumerate(processor.worker_tasks)
        try
            wait(task)
            @info "Worker $(processor.worker_pids[i]) stopped"
        catch e
            @warn "Error waiting for worker $(processor.worker_pids[i])" exception=e
        end
    end

    return
end

export JobProcessor, start, stop, put!, isbusy
