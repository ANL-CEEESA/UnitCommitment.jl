# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2025, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using Backend
using Test
using HiGHS

function jobs_test_usage()
    @testset "JobProcessor" begin
        # Setup job directory
        job_id = "qwe123"
        job_dir = joinpath(Backend.basedir, "jobs", job_id)
        mkpath(job_dir)
        cp(fixture("case14.json.gz"), joinpath(job_dir, "input.json.gz"))

        try
            # Create processor with HiGHS optimizer
            processor = JobProcessor(optimizer = HiGHS.Optimizer)

            # Start the worker
            start(processor)

            # Push job to queue
            put!(processor, job_id)

            # Stop worker (wait for jobs to finish)
            sleep(0.1)
            stop(processor)

            # Check that solution file exists
            output_path = joinpath(job_dir, "output.json")
            @test isfile(output_path)
        finally
            # Cleanup
            rm(job_dir, recursive = true, force = true)
        end
    end
end
