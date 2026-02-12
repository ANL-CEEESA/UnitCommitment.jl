# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using MPI

@testfunction methods_ProgressiveHedging_usage_test begin
    basedir = dirname(@__FILE__)
    mpiexec() do exe
        return run(
            `$exe -n 2 $(Base.julia_cmd()) --project=test $basedir/ph.jl`,
        )
    end
end
