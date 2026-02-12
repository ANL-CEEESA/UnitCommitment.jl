# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

function read(
    paths::Vector{String},
    ::ProgressiveHedging,
)::UnitCommitmentInstance
    comm = MPI.COMM_WORLD
    mpi = MpiInfo(comm)
    (length(paths) % mpi.nprocs == 0) || error(
        "Number of processes $(mpi.nprocs) is not a divisor of $(length(paths))",
    )
    bundled_scenarios = length(paths) ÷ mpi.nprocs
    sc_num_start = (mpi.rank - 1) * bundled_scenarios + 1
    sc_num_end = mpi.rank * bundled_scenarios
    instance = read(paths[sc_num_start:sc_num_end])

    # Remove the LMP extension
    filter!(ext -> extension_slot(ext) != :lmp, instance.extensions)
    delete!(instance.extension_by_slot, :lmp)

    # Return
    return instance
end
