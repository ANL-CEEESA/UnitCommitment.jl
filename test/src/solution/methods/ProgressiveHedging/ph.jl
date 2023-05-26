using HiGHS
using MPI
using JuMP
using UnitCommitment

UnitCommitment._setup_logger(level = Base.CoreLogging.Error)
function fixture(path::String)::String
    basedir = dirname(@__FILE__)
    return "$basedir/../../../../fixtures/$path"
end

# Initialize MPI
MPI.Init()

# Configure progressive hedging method
ph = UnitCommitment.ProgressiveHedging()

# Read problem instance
instance = UnitCommitment.read(
    [fixture("case14.json.gz"), fixture("case14.json.gz")],
    ph,
)

# Build JuMP model
model = UnitCommitment.build_model(
    instance = instance,
    optimizer = optimizer_with_attributes(
        HiGHS.Optimizer,
        MOI.Silent() => true,
    ),
)

# Run the decentralized optimization algorithm
UnitCommitment.optimize!(model, ph)

# Fetch the solution
solution = UnitCommitment.solution(model, ph)

# Close MPI
MPI.Finalize()
