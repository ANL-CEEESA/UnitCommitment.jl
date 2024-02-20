# Decomposition methods

## 1. Time decomposition

Solving unit commitment instances that have long time horizons (for example, year-long 8760-hour instances) requires a substantial amount of computational power. To address this issue, UC.jl offers a time decomposition method, which breaks the instance down into multiple overlapping subproblems, solves them sequentially, then reassembles the solution.

When solving a unit commitment instance with a dense time slot structure, computational complexity can become a significant challenge. For instance, if the instance contains hourly data for an entire year (8760 hours), solving such a model can require a substantial amount of computational power. To address this issue, UC.jl provides a time_decomposition method within the `optimize!` function. This method decomposes the problem into multiple sub-problems, solving them sequentially.

The `optimize!` function takes 5 parameters: a unit commitment instance, a `TimeDecomposition` method, an optimizer, and two optional functions `after_build` and `after_optimize`. It returns a solution dictionary. The `TimeDecomposition` method itself requires four arguments: `time_window`, `time_increment`, `inner_method` (optional), and `formulation` (optional). These arguments define the time window for each sub-problem, the time increment to move to the next sub-problem, the method used to solve each sub-problem, and the formulation employed, respectively. The two functions, namely `after_build` and `after_optimize`, are invoked subsequent to the construction and optimization of each sub-model, respectively. It is imperative that the `after_build` function requires its two arguments to be consistently mapped to `model` and `instance`, while the `after_optimize` function necessitates its three arguments to be consistently mapped to `solution`, `model`, and `instance`.

The code snippet below illustrates an example of solving an instance by decomposing the model into multiple 36-hour sub-problems using the `XavQiuWanThi2019` method. Each sub-problem advances 24 hours at a time. The first sub-problem covers time steps 1 to 36, the second covers time steps 25 to 60, the third covers time steps 49 to 84, and so on. The initial power levels and statuses of the second and subsequent sub-problems are set based on the results of the first 24 hours from each of their immediate prior sub-problems. In essence, this approach addresses the complexity of solving a large problem by tackling it in 24-hour intervals, while incorporating an additional 12-hour buffer to mitigate the closing window effect for each sub-problem. Furthermore, the `after_build` function imposes the restriction that `g3` and `g4` cannot be activated simultaneously during the initial time slot of each sub-problem. On the other hand, the `after_optimize` function is invoked to calculate the conventional Locational Marginal Prices (LMPs) for each sub-problem, and subsequently appends the computed values to the `lmps` vector.

> **Warning**
> Specifying `TimeDecomposition` as the value of the `inner_method` field of another `TimeDecomposition` causes errors when calling the `optimize!` function due to the different argument structures between the two `optimize!` functions.

```julia
using UnitCommitment, JuMP, Cbc, HiGHS

import UnitCommitment:
    TimeDecomposition,
    ConventionalLMP,
    XavQiuWanThi2019,
    Formulation

# specifying the after_build and after_optimize functions
function after_build(model, instance)
    @constraint(
        model,
        model[:is_on]["g3", 1] + model[:is_on]["g4", 1] <= 1,
    )
end

lmps = []
function after_optimize(solution, model, instance)
    lmp = UnitCommitment.compute_lmp(
        model,
        ConventionalLMP(),
        optimizer = HiGHS.Optimizer,
    )
    return push!(lmps, lmp)
end

# assume the instance is given as a 120h problem
instance = UnitCommitment.read("instance.json")

solution = UnitCommitment.optimize!(
    instance,
    TimeDecomposition(
        time_window = 36,  # solve 36h problems
        time_increment = 24,  # advance by 24h each time
        inner_method = XavQiuWanThi2019.Method(),
        formulation = Formulation(),
    ),
    optimizer = Cbc.Optimizer,
    after_build = after_build,
    after_optimize = after_optimize,
)
```

## 2. Scenario decomposition with Progressive Hedging

By default, UC.jl uses the Extensive Form (EF) when solving stochastic instances. This approach involves constructing a single JuMP model that contains data and decision variables for all scenarios. Although EF has optimality guarantees and performs well with small test cases, it can become computationally intractable for large instances or substantial number of scenarios.

Progressive Hedging (PH) is an alternative (heuristic) solution method provided by UC.jl in which the problem is decomposed into smaller scenario-based subproblems, which are then solved in parallel in separate Julia processes, potentially across multiple machines. Quadratic penalty terms are used to enforce convergence of first-stage decision variables. The method is closely related to the Alternative Direction Method of Multipliers (ADMM) and can handle larger instances, although it is not guaranteed to converge to the optimal solution. Our implementation of PH relies on Message Passing Interface (MPI) for communication. We refer to [MPI.jl Documentation](https://github.com/JuliaParallel/MPI.jl) for more details on installing MPI.

The following example shows how to solve SCUC instances using progressive hedging. The script should be saved in a file, say `ph.jl`, and executed using `mpiexec -n <num-scenarios> julia ph.jl`.

```julia
using HiGHS
using MPI
using UnitCommitment
using Glob

# 1. Initialize MPI
MPI.Init()

# 2. Configure progressive hedging method
ph = UnitCommitment.ProgressiveHedging()

# 3. Read problem instance
instance = UnitCommitment.read(["example/s1.json", "example/s2.json"], ph)

# 4. Build JuMP model
model = UnitCommitment.build_model(
    instance = instance,
    optimizer = HiGHS.Optimizer,
)

# 5. Run the decentralized optimization algorithm
UnitCommitment.optimize!(model, ph)

# 6. Fetch the solution
solution = UnitCommitment.solution(model, ph)

# 7. Close MPI
MPI.Finalize()
```

When using PH, the model can be customized as usual, with different formulations or additional user-provided constraints. Note that `read`, in this case, takes `ph` as an argument. This allows each Julia process to read only the instance files that are relevant to it. Similarly, the `solution` function gathers the optimal solution of each processes and returns a combined dictionary.

Each process solves a sub-problem with $\frac{s}{p}$ scenarios, where $s$ is the total number of scenarios and $p$ is the number of MPI processes. For instance, if we have 15 scenario files and 5 processes, then each process will solve a JuMP model that contains data for 3 scenarios. If the total number of scenarios is not divisible by the number of processes, then an error will be thrown.

!!! warning

    Currently, PH can handle only equiprobable scenarios. Further, `solution(model, ph)` can only handle cases where only one scenario is modeled in each process.
