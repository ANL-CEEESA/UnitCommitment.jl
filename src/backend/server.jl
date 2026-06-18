# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using HTTP
using HTTP: Router
using SHA
using CodecZlib
using JSON

mutable struct ServerHandle
    server::HTTP.Server
    processor::JobProcessor
    stopped::Bool
end

const _RESPONSE_HEADERS = [
    "Access-Control-Allow-Origin" => "*",
    "Access-Control-Allow-Methods" => "GET, POST, OPTIONS",
    "Access-Control-Allow-Headers" => "Content-Type",
]

function _submit(req, processor::JobProcessor, jobs_dir::String)
    # Check if request body is empty
    compressed_body = HTTP.payload(req)
    if isempty(compressed_body)
        return HTTP.Response(400, _RESPONSE_HEADERS, "Error: No file provided")
    end

    # Validate compressed JSON by decompressing and parsing
    decompressed_data = try
        transcode(GzipDecompressor, compressed_body)
    catch e
        return HTTP.Response(
            400,
            _RESPONSE_HEADERS,
            "Error: Invalid compressed JSON",
        )
    end

    # Generate job ID from SHA-256 hash of decompressed data
    job_id = bytes2hex(sha256(decompressed_data))[1:16]

    # Check if job already exists
    job_dir = joinpath(jobs_dir, job_id)
    if isdir(job_dir)
        response_body = JSON.json(Dict("job_id" => job_id))
        return HTTP.Response(200, _RESPONSE_HEADERS, response_body)
    end

    # Create job directory
    mkpath(job_dir)

    # Save input file
    json_path = joinpath(job_dir, "input.json.gz")
    Base.write(json_path, compressed_body)

    # Add job to queue
    put!(processor, job_id)

    # Return job ID as JSON
    response_body = JSON.json(Dict("job_id" => job_id))
    return HTTP.Response(200, _RESPONSE_HEADERS, response_body)
end

function _jobs_view(req, processor, jobs_dir::String)
    # Extract job_id from URL path /api/jobs/{job_id}/view
    path_parts = split(req.target, '/')
    job_id = path_parts[4]

    # Construct job directory path
    job_dir = joinpath(jobs_dir, job_id)

    # Check if job directory exists
    if !isdir(job_dir)
        return HTTP.Response(404, _RESPONSE_HEADERS, "Job not found")
    end

    # Read log file if it exists
    log_path = joinpath(job_dir, "output.log")
    log_content = isfile(log_path) ? Base.read(log_path, String) : nothing

    # Read output.json if it exists
    output_path = joinpath(job_dir, "output.json")
    output_content =
        isfile(output_path) ? Base.read(output_path, String) : nothing

    # Read and decompress input.json.gz if solution exists
    input_content = nothing
    if output_content !== nothing
        input_path = joinpath(job_dir, "input.json.gz")
        if isfile(input_path)
            compressed_input = Base.read(input_path)
            decompressed_input = transcode(GzipDecompressor, compressed_input)
            input_content = String(decompressed_input)
        end
    end

    # Read job status
    job_status = "unknown"
    if output_content !== nothing
        job_status = "completed"
    elseif haskey(processor.job_status, job_id)
        job_status = processor.job_status[job_id]
    end

    # Read job position (0 if already processed or not found)
    job_position = get(processor.job_position, job_id, 0)

    # Create response JSON
    response_data = Dict(
        "log" => log_content,
        "solution" => output_content,
        "input" => input_content,
        "status" => job_status,
        "position" => job_position,
    )
    response_body = JSON.json(response_data)
    return HTTP.Response(200, _RESPONSE_HEADERS, response_body)
end

function start_backend(
    host::String = "127.0.0.1",
    port::Int = 9000;
    milp_optimizer,
    minlp_optimizer,
    method = nothing,
    jobs_dir::String = mktempdir(),
)
    function work_fn(job_id)
        job_dir = joinpath(jobs_dir, job_id)
        mkpath(job_dir)
        input_filename = joinpath(job_dir, "input.json.gz")
        log_filename = joinpath(job_dir, "output.log")
        solution_filename = joinpath(job_dir, "output.json")
        try
            open(log_filename, "w") do io
                redirect_stdout(io) do
                    redirect_stderr(io) do
                        compressed = Base.read(input_filename)
                        json = JSON.parse(
                            String(transcode(GzipDecompressor, compressed)),
                        )
                        if haskey(json, "extensions")
                            job_extensions =
                                _parse_extensions(json["extensions"])
                            instance = UnitCommitment.read(
                                input_filename;
                                extensions = job_extensions,
                            )
                        else
                            instance = UnitCommitment.read(input_filename)
                        end
                        optimizer =
                            if instance.extension_by_slot[:transmission] isa ACTransmissionExt
                                minlp_optimizer
                            else
                                milp_optimizer
                            end
                        model =
                            UnitCommitment.build_model(; instance, optimizer)
                        if method !== nothing
                            UnitCommitment.optimize!(model, method)
                        else
                            UnitCommitment.optimize!(model)
                        end
                        solution = UnitCommitment.solution(model)
                        UnitCommitment.write(solution_filename, solution)
                        return
                    end
                end
            end
        catch e
            open(log_filename, "a") do io
                println(io, "\nError: ", e)
                println(io, "\nStacktrace:")
                return Base.show_backtrace(io, catch_backtrace())
            end
        end
        return
    end

    # Create and start job processor
    processor = JobProcessor(; work_fn)
    _start_processor(processor)

    router = HTTP.Router()

    # Register CORS preflight endpoint
    HTTP.register!(
        router,
        "OPTIONS",
        "/**",
        req -> HTTP.Response(200, _RESPONSE_HEADERS, ""),
    )

    # Register /submit endpoint
    HTTP.register!(
        router,
        "POST",
        "/api/submit",
        req -> _submit(req, processor, jobs_dir),
    )

    # Register job/*/view endpoint
    HTTP.register!(
        router,
        "GET",
        "/api/jobs/*/view",
        req -> _jobs_view(req, processor, jobs_dir),
    )

    server = HTTP.serve!(router, host, port; verbose = false)
    return ServerHandle(server, processor, false)
end

function stop_backend(handle::ServerHandle)
    handle.stopped && return nothing
    handle.stopped = true
    _stop_processor(handle.processor)
    close(handle.server)
    return nothing
end

function Base.wait(handle::ServerHandle)
    try
        wait(handle.server)
    catch e
        e isa InterruptException || rethrow(e)
    finally
        stop_backend(handle)
    end
end
