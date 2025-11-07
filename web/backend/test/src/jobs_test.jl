# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2025, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using Backend
using Test

function jobs_test_usage()
    @testset "JobProcessor" begin
        # Define dummy work function
        received_job_id = []
        function work_fn(job_id)
            @show received_job_id
            push!(received_job_id, job_id)
        end

        # Create processor with work function
        processor = JobProcessor(; work_fn)

        # Start the worker
        start(processor)

        # Push job to queue
        put!(processor, "test")

        # Wait for job to complete
        sleep(0.1)
        stop(processor)

        # Check that the work function was called with correct job_id
        @test received_job_id[1] == "test"
    end
end
