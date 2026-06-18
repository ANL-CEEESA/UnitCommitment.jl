# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using HTTP

@testfunction backend_server_test begin
    host = "127.0.0.1"
    port = 32617
    jobs_dir = mktempdir()

    server = UnitCommitment.start_backend(
        host,
        port;
        milp_optimizer = HiGHS.Optimizer,
        minlp_optimizer = _minlp_optimizer(),
        jobs_dir = jobs_dir,
    )
    try
        # Read the compressed fixture file
        compressed_data = read(fixture("case14.json.gz"))

        # Submit test case
        response = HTTP.post(
            "http://$host:$port/api/submit",
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
        sleep(10)

        # Verify the compressed file was saved correctly
        job_dir = joinpath(jobs_dir, job_id)
        saved_input_path = joinpath(job_dir, "input.json.gz")
        saved_log_path = joinpath(job_dir, "output.log")
        saved_output_path = joinpath(job_dir, "output.json")
        @test isfile(saved_input_path)
        @test isfile(saved_log_path)
        @test isfile(saved_output_path)
        saved_data = read(saved_input_path)
        @test saved_data == compressed_data

        # Query job information
        view_response = HTTP.get("http://$host:$port/api/jobs/$job_id/view")
        @test view_response.status == 200

        # Check response
        view_data = JSON.parse(String(view_response.body))
        @test haskey(view_data, "log")
        @test haskey(view_data, "solution")
        @test view_data["log"] !== nothing
        @test view_data["solution"] !== nothing
        @test view_data["status"] == "completed"
    finally
        UnitCommitment.stop_backend(server)
        rm(jobs_dir; recursive = true, force = true)
    end
end
