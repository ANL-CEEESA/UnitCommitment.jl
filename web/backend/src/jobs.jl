# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2025, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using Distributed
import Base: put!

Base.@kwdef mutable struct JobProcessor
    pending = RemoteChannel(() -> Channel{String}(Inf))
    processing = RemoteChannel(() -> Channel{String}(Inf))
    shutdown = RemoteChannel(() -> Channel{Bool}(1))
    worker_pid = nothing
    monitor_task = nothing
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
    processor.monitor_task = @spawn begin
        worker_loop(
            processor.pending,
            processor.processing,
            processor.shutdown,
            processor.work_fn,
        )
    end
    return
end

function stop(processor::JobProcessor)
    put!(processor.shutdown, true)
    if processor.monitor_task !== nothing
        try
            wait(processor.monitor_task)
        catch e
            @warn "Error waiting for worker task" exception=e
        end
    end
    return
end

export JobProcessor, start, stop, put!, isbusy
