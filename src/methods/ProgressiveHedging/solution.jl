# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using MPI, DataStructures, Serialization

function solution(
    model::UnitCommitmentModel,
    method::ProgressiveHedging,
)::OrderedDict
    comm = MPI.COMM_WORLD
    mpi = MpiInfo(comm)
    local_sol = UnitCommitment.solution(model)

    # Serialize local solution to bytes
    io = IOBuffer()
    serialize(io, local_sol)
    local_bytes = take!(io)

    # Gather sizes so root can allocate receive buffer
    all_sizes = MPI.Gather(Int32[length(local_bytes)], comm)

    # Gather serialized solutions using variable-length gather
    if mpi.root
        counts = vec(all_sizes)
        recvbuf = MPI.VBuffer(Vector{UInt8}(undef, sum(counts)), counts)
        MPI.Gatherv!(local_bytes, recvbuf, comm)
        result = OrderedDict{String,Any}()
        offset = 0
        for i in 1:mpi.nprocs
            rank_sol =
                deserialize(IOBuffer(recvbuf.data[offset+1:offset+counts[i]]))
            result["rank_$i"] = rank_sol
            offset += counts[i]
        end
        return result
    else
        MPI.Gatherv!(local_bytes, nothing, comm)
        return OrderedDict()
    end
end
