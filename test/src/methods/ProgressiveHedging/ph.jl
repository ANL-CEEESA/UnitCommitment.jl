using SCIP
using MPI
using JuMP
using UnitCommitment

function fixture(path::String)::String
    basedir = dirname(@__FILE__)
    return "$basedir/../../../fixtures/$path"
end

MPI.Init()
mpi = UnitCommitment.MpiInfo(MPI.COMM_WORLD)
instances = [fixture("case14/base.json"), fixture("case14/base.json")]

ph = UnitCommitment.ProgressiveHedging()
instance = UnitCommitment.read(instances, ph)
model = build_model(
    instance,
    optimizer = optimizer_with_attributes(
        SCIP.Optimizer,
        "display/verblevel" => (mpi.rank == 1 ? 1 : 0),
    ),
)
optimize!(model, ph)
sol = solution(model, ph)

MPI.Finalize()
