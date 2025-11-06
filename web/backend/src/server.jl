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
    return HTTP.Response(200, "OK")
end

function start_server(port::Int = 8080; optimizer)
    Random.seed!()

    # Create and start job processor
    processor = JobProcessor(optimizer = optimizer)
    start(processor)

    router = HTTP.Router()

    # Register /submit endpoint
    HTTP.register!(router, "POST", "/submit", req -> submit(req, processor))

    # Register job/*/view endpoint
    HTTP.register!(router, "GET", "/jobs/*/view", jobs_view)

    server = HTTP.serve!(router, port; verbose = false)
    return ServerHandle(server, processor)
end

function stop(handle::ServerHandle)
    stop(handle.processor)
    close(handle.server)
    return nothing
end
