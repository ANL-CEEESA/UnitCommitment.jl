using HTTP
using Random
using JSON
using CodecZlib
using UnitCommitment

struct ServerHandle
    server::HTTP.Server
    processor::JobProcessor
end

function submit(req, processor::JobProcessor)
    # Check if request body is empty
    compressed_body = HTTP.payload(req)
    if isempty(compressed_body)
        return HTTP.Response(400, "Error: No file provided")
    end

    # Validate compressed JSON by decompressing and parsing
    try
        decompressed_data = transcode(GzipDecompressor, compressed_body)
        JSON.parse(String(decompressed_data))
    catch e
        return HTTP.Response(400, "Error: Invalid compressed JSON")
    end

    # Generate random job ID (lowercase letters and numbers)
    job_id = randstring(['a':'z'; '0':'9'], 16)

    # Create job directory
    job_dir = joinpath(basedir, "jobs", job_id)
    mkpath(job_dir)

    # Save input file
    json_path = joinpath(job_dir, "input.json.gz")
    write(json_path, compressed_body)

    # Add job to queue
    put!(processor, job_id)

    # Return job ID as JSON
    response_body = JSON.json(Dict("job_id" => job_id))
    return HTTP.Response(200, response_body)
end

function jobs_view(req)
    # Extract job_id from URL path /jobs/{job_id}/view
    path_parts = split(req.target, '/')
    job_id = path_parts[3]  # /jobs/{job_id}/view -> index 3

    # Construct job directory path
    job_dir = joinpath(basedir, "jobs", job_id)

    # Check if job directory exists
    if !isdir(job_dir)
        return HTTP.Response(404, "Job not found")
    end

    # Read log file if it exists
    log_path = joinpath(job_dir, "output.log")
    log_content = isfile(log_path) ? read(log_path, String) : nothing

    # Read output.json if it exists
    output_path = joinpath(job_dir, "output.json")
    output_content = isfile(output_path) ? read(output_path, String) : nothing

    # Create response JSON
    response_data = Dict(
        "log" => log_content,
        "solution" => output_content
    )

    response_body = JSON.json(response_data)
    return HTTP.Response(200, response_body)
end

function start_server(host, port; optimizer)
    Random.seed!()

    function work_fn(job_id)
        job_dir = joinpath(basedir, "jobs", job_id)
        mkpath(job_dir)
        input_filename = joinpath(job_dir, "input.json.gz")
        log_filename = joinpath(job_dir, "output.log")
        solution_filename = joinpath(job_dir, "output.json")
        try
            open(log_filename, "w") do io
                redirect_stdout(io) do
                    redirect_stderr(io) do
                        instance = UnitCommitment.read(input_filename)
                        model = UnitCommitment.build_model(;
                            instance,
                            optimizer = optimizer,
                        )
                        UnitCommitment.optimize!(model)
                        solution = UnitCommitment.solution(model)
                        UnitCommitment.write(solution_filename, solution)
                    end
                end
            end
        catch e
            @error "Failed job: $job_id" e
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
    start(processor)

    router = HTTP.Router()

    # Register /submit endpoint
    HTTP.register!(router, "POST", "/submit", req -> submit(req, processor))

    # Register job/*/view endpoint
    HTTP.register!(router, "GET", "/jobs/*/view", jobs_view)

    server = HTTP.serve!(router, host, port; verbose = false)
    return ServerHandle(server, processor)
end

function stop(handle::ServerHandle)
    stop(handle.processor)
    close(handle.server)
    return nothing
end
