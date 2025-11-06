# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2025, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

module Backend

using HTTP
using Random
using JSON
using CodecZlib
using UnitCommitment

basedir = joinpath(dirname(@__FILE__), "..")

function submit(req; optimizer)
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

    # Optimize file
    instance = UnitCommitment.read(json_path)
    model = UnitCommitment.build_model(; instance, optimizer)
    UnitCommitment.optimize!(model)
    solution = UnitCommitment.solution(model)
    UnitCommitment.write("$job_dir/output.json", solution)

    # Return job ID as JSON
    response_body = JSON.json(Dict("job_id" => job_id))
    return HTTP.Response(200, response_body)
end

function jobs_view(req)
    return HTTP.Response(200, "OK")
end


function start_server(port::Int = 8080; optimizer)
    Random.seed!()
    router = HTTP.Router()
    HTTP.register!(router, "POST", "/submit", req -> submit(req; optimizer))
    HTTP.register!(router, "GET", "/jobs/*/view", jobs_view)
    server = HTTP.serve!(router, port; verbose = false)
    return server
end

end
