# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2025, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using Backend
using Test

function jobs_test_usage()
    @testset "JobProcessor" begin
        # Create a temporary directory for test output
        test_dir = mktempdir()

        # Define dummy work function that writes to a file
        # Note: This function will be executed on a worker process
        function work_fn(job_id)
            output_file = joinpath(test_dir, job_id * ".txt")
            write(output_file, job_id)
            return
        end

        # Create processor with work function
        processor = JobProcessor(; work_fn)

        # Start the worker
        start(processor)

        # Push job to queue
        put!(processor, "test")

        # Wait for job to complete
        # Increased timeout to account for worker process startup
        sleep(2)
        stop(processor)

        # Check that the work function was called with correct job_id
        output_file = joinpath(test_dir, "test.txt")
        @test isfile(output_file)
        @test read(output_file, String) == "test"

        # Clean up
        rm(test_dir; recursive = true)
    end
end
