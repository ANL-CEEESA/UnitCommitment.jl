using Cbc
using MPI
using JuMP
using UnitCommitment

UnitCommitment._setup_logger(level = Base.CoreLogging.Error)
function fixture(path::String)::String
    basedir = dirname(@__FILE__)
    return "$basedir/../../../../fixtures/$path"
end

# 1. Initialize MPI
MPI.Init()

# 2. Configure progressive hedging method
ph = UnitCommitment.ProgressiveHedging()

# 3. Read problem instance
instance = UnitCommitment.read(
    [fixture("case14.json.gz"), fixture("case14.json.gz")],
    ph,
)

# 4. Build JuMP model
model = UnitCommitment.build_model(
    instance = instance,
    optimizer = optimizer_with_attributes(Cbc.Optimizer, "LogLevel" => 0),
)

# 5. Run the decentralized optimization algorithm
UnitCommitment.optimize!(model, ph)

# 6. Fetch the solution
solution = UnitCommitment.solution(model, ph)

# 7. Close MPI
MPI.Finalize()
