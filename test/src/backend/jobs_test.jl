# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

@testfunction backend_jobs_test begin
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
    processor = UnitCommitment.JobProcessor(; work_fn)

    # Start the worker
    UnitCommitment._start_processor(processor)

    # Push job to queue
    put!(processor, "test")

    # Wait for job to complete
    sleep(2)
    UnitCommitment._stop_processor(processor)

    # Check that the work function was called with correct job_id
    output_file = joinpath(test_dir, "test.txt")
    @test isfile(output_file)
    @test read(output_file, String) == "test"

    # Clean up
    rm(test_dir; recursive = true)
end
