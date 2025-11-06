# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2025, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

module BackendT

using Test
using HTTP
using JSON
using CodecZlib
import Backend
import JuliaFormatter
using HiGHS

basedir = dirname(@__FILE__)
port = 32617

function fixture(path::String)::String
    return "$basedir/../fixtures/$path"
end

function with_server(f)
    logger = Test.TestLogger()
    # server = Base.CoreLogging.with_logger(logger) do
    #     Backend.start_server(port)
    # end
    server = Backend.start_server(port; optimizer=HiGHS.Optimizer)
    try
        f()
    finally
        close(server)
    end
    return filter!(x -> x.group == :access, logger.logs)
end

function test_usage()
    with_server() do
        # Read the compressed fixture file
        compressed_data = read(fixture("case14.json.gz"))

        # Submit test case
        response = HTTP.post(
            "http://localhost:$port/submit",
            ["Content-Type" => "application/gzip"],
            compressed_data
        )
        @test response.status == 200

        # Check response
        response_data = JSON.parse(String(response.body))
        @test haskey(response_data, "job_id")
        job_id = response_data["job_id"]
        @test length(job_id) == 16
        @test all(c -> c in ['a':'z'; '0':'9'], collect(job_id))

        # Verify the compressed file was saved correctly
        job_dir = joinpath(Backend.basedir, "jobs", job_id)
        saved_path = joinpath(job_dir, "input.json.gz")
        @test isfile(saved_path)
        saved_data = read(saved_path)
        @test saved_data == compressed_data

        response = HTTP.get("http://localhost:$port/jobs/123/view")
        @test response.status == 200
        @test String(response.body) == "OK"

        # Clean up: remove the job directory
        # rm(job_dir, recursive=true)
    end
end

function runtests()
    @testset "UCJL Backend" begin
        test_usage()
    end
    return
end

function format()
    JuliaFormatter.format(basedir, verbose = true)
    JuliaFormatter.format("$basedir/../../src", verbose = true)
    return
end

export runtests, format

end
