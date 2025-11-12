# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2025, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

const HOST = "127.0.0.1"
const PORT = 32617

function server_test_usage()
    server = Backend.start_server(HOST, PORT; optimizer = HiGHS.Optimizer)
    try
        # Read the compressed fixture file
        compressed_data = read(fixture("case14.json.gz"))

        # Submit test case
        response = HTTP.post(
            "http://$HOST:$PORT/api/submit",
            ["Content-Type" => "application/gzip"],
            compressed_data,
        )
        @test response.status == 200

        # Check response
        response_data = JSON.parse(String(response.body))
        @test haskey(response_data, "job_id")
        job_id = response_data["job_id"]
        @test length(job_id) == 16

        # Wait for jobs to finish
        sleep(5)
        while isbusy(server.processor)
            sleep(0.1)
        end

        # Verify the compressed file was saved correctly
        job_dir = joinpath(Backend.basedir, "jobs", job_id)
        saved_input_path = joinpath(job_dir, "input.json.gz")
        saved_log_path = joinpath(job_dir, "output.log")
        saved_output_path = joinpath(job_dir, "output.json")
        @test isfile(saved_input_path)
        @test isfile(saved_log_path)
        @test isfile(saved_output_path)
        saved_data = read(saved_input_path)
        @test saved_data == compressed_data

        # Query job information
        view_response = HTTP.get("http://$HOST:$PORT/api/jobs/$job_id/view")
        @test view_response.status == 200

        # Check response
        view_data = JSON.parse(String(view_response.body))
        @test haskey(view_data, "log")
        @test haskey(view_data, "solution")
        @test view_data["log"] !== nothing
        @test view_data["solution"] !== nothing

        # Clean up
        rm(job_dir, recursive = true)
    finally
        stop(server)
    end
end
