# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using Distributed
import Base: put!

Base.@kwdef mutable struct JobProcessor
    pending = RemoteChannel(() -> Channel{String}(Inf))
    processing = RemoteChannel(() -> Channel{String}(Inf))
    completed = RemoteChannel(() -> Channel{String}(Inf))
    shutdown = RemoteChannel(() -> Channel{Bool}(1))
    worker_pids = []
    worker_tasks = []
    work_fn = nothing
    master_task = nothing
    job_status = Dict()
    job_position = Dict()
    pending_queue = []
end

function _update_positions!(processor::JobProcessor)
    for (i, job_id) in enumerate(processor.pending_queue)
        processor.job_position[job_id] = i
    end
end

function Base.put!(processor::JobProcessor, job_id::String)
    put!(processor.pending, job_id)
    processor.job_status[job_id] = "pending"
    push!(processor.pending_queue, job_id)
    return _update_positions!(processor)
end

function _master_loop(processor)
    @info "Starting master loop"
    while true
        # Check for shutdown signal
        if isready(processor.shutdown)
            break
        end

        # Check for processing jobs
        while isready(processor.processing)
            job_id = take!(processor.processing)
            processor.job_status[job_id] = "processing"
            filter!(x -> x != job_id, processor.pending_queue)
            delete!(processor.job_position, job_id)
            _update_positions!(processor)
        end

        # Check for completed jobs
        while isready(processor.completed)
            job_id = take!(processor.completed)
            delete!(processor.job_status, job_id)
            delete!(processor.job_position, job_id)
        end

        sleep(0.1)
    end
end

function _worker_loop(pending, processing, completed, shutdown, work_fn)
    @info "Starting worker loop"
    while true
        # Check for shutdown signal
        if isready(shutdown)
            break
        end

        # Check for pending tasks
        if isready(pending)
            job_id = take!(pending)
            put!(processing, job_id)
            @info "Job started: $job_id"
            try
                work_time = @elapsed work_fn(job_id)
                @info "Job finished: $job_id ($work_time s)"
                put!(completed, job_id)
            catch e
                @error "Job failed: job $job_id"
            end
        end

        sleep(0.1)
    end
end

function _start_processor(processor::JobProcessor)
    # Get list of available worker processes
    worker_pids = workers()
    @info "Starting job processor with $(length(worker_pids)) worker(s)"

    # Start a worker loop on each worker process
    for pid in worker_pids
        task = @spawnat pid begin
            _worker_loop(
                processor.pending,
                processor.processing,
                processor.completed,
                processor.shutdown,
                processor.work_fn,
            )
        end
        push!(processor.worker_pids, pid)
        push!(processor.worker_tasks, task)
    end

    # Start master loop (after spawning workers to avoid serialization issues)
    processor.master_task = @async _master_loop(processor)

    return
end

function _stop_processor(processor::JobProcessor)
    put!(processor.shutdown, true)
    wait(processor.master_task)
    for (i, task) in enumerate(processor.worker_tasks)
        wait(task)
    end
    return
end
