Usage
=====

Installation
------------

UnitCommitment.jl was tested and developed with [Julia 1.9](https://julialang.org/). To install Julia, please follow the [installation guide on the official Julia website](https://julialang.org/downloads/). To install UnitCommitment.jl, run the Julia interpreter, type `]` to open the package manager, then type:

```text
pkg> add UnitCommitment@0.4
```

To solve the optimization models, a mixed-integer linear programming (MILP) solver is also required. Please see the [JuMP installation guide](https://jump.dev/JuMP.jl/stable/installation/) for more instructions on installing a solver. Typical open-source choices are [HiGHS](https://github.com/jump-dev/HiGHS.jl), [Cbc](https://github.com/JuliaOpt/Cbc.jl) and [GLPK](https://github.com/JuliaOpt/GLPK.jl). In the instructions below, Cbc will be used, but any other MILP solver listed in JuMP installation guide should also be compatible.

Typical Usage
-------------

### Solving user-provided instances

The first step to use UC.jl is to construct JSON files that describe each scenario of your stochastic unit commitment instance. See [Data Format](format.md) for a complete description of the data format UC.jl expects. The next steps, as shown below, are to: (1) read the scenario files; (2) build the optimization model; (3) run the optimization; and (4) extract the optimal solution.

!!! note

> By default, UC.jl uses the extensive form to solve the problem. For a more advanced solution method, see below. 

```julia
using Cbc
using JSON
using UnitCommitment

# 1. Read instance
instance = UnitCommitment.read(["/path/to/s1.json", "/path/to/s2.json"])

# 2. Construct optimization model
model = UnitCommitment.build_model(
    instance=instance,
    optimizer=Cbc.Optimizer,
)

# 3. Solve model
UnitCommitment.optimize!(model)

# 4. Write solution to a file
solution = UnitCommitment.solution(model)
UnitCommitment.write("/path/to/output.json", solution)
```

To read all files in a given folder, the [Glob](https://github.com/vtjnash/Glob.jl) package can be used:

```julia
using Glob
instance = UnitCommitment.read(glob("*.json", "/path/to/scenarios/"))
```

To solve deterministic instances, a single scenario file may be provided.

```julia
instance = UnitCommitment.read("/path/to/s1.json")
```

### Solving benchmark instances

UnitCommitment.jl contains a large number of deterministic benchmark instances collected from the literature and converted into a common data format. To solve one of these instances individually, instead of constructing your own, the function `read_benchmark` can be used, as shown below. See [Instances](instances.md) for the complete list of available instances.

```julia
instance = UnitCommitment.read_benchmark("matpower/case3375wp/2017-02-01")
```

## Customizing the formulation

By default, `build_model` uses a formulation that combines modeling components from different publications, and that has been carefully tested, using our own benchmark scripts, to provide good performance across a wide variety of instances. This default formulation is expected to change over time, as new methods are proposed in the literature. You can, however, construct your own formulation, based on the modeling components that you choose, as shown in the next example.

```julia
using Cbc
using UnitCommitment

import UnitCommitment:
    Formulation,
    KnuOstWat2018,
    MorLatRam2013,
    ShiftFactorsFormulation

instance = UnitCommitment.read_benchmark(
    "matpower/case118/2017-02-01",
)

model = UnitCommitment.build_model(
    instance = instance,
    optimizer = Cbc.Optimizer,
    formulation = Formulation(
        pwl_costs = KnuOstWat2018.PwlCosts(),
        ramping = MorLatRam2013.Ramping(),
        startup_costs = MorLatRam2013.StartupCosts(),
        transmission = ShiftFactorsFormulation(
            isf_cutoff = 0.005,
            lodf_cutoff = 0.001,
        ),
    ),
)
```

## Generating initial conditions

When creating random unit commitment instances for benchmark purposes, it is often hard to compute, in advance, sensible initial conditions for all generators. Setting initial conditions naively (for example, making all generators initially off and producing no power) can easily cause the instance to become infeasible due to excessive ramping. Initial conditions can also make it hard to modify existing instances. For example, increasing the system load without carefully modifying the initial conditions may make the problem infeasible or unrealistically challenging to solve.

To help with this issue, UC.jl provides a utility function which can generate feasible initial conditions by solving a single-period optimization problem, as shown below:

```julia
using Cbc
using UnitCommitment

# Read original instance
instance = UnitCommitment.read("instance.json")

# Generate initial conditions (in-place)
UnitCommitment.generate_initial_conditions!(instance, Cbc.Optimizer)

# Construct and solve optimization model
model = UnitCommitment.build_model(
    instance=instance,
    optimizer=Cbc.Optimizer,
)
UnitCommitment.optimize!(model)
```

!!! warning

    The function `generate_initial_conditions!` may return different initial conditions after each call, even if the same instance and the same optimizer is provided. The particular algorithm may also change in a future version of UC.jl. For these reasons, it is recommended that you generate initial conditions exactly once for each instance and store them for later use.
    
## Verifying solutions

When developing new formulations, it is very easy to introduce subtle errors in the model that result in incorrect solutions. To help with this, UC.jl includes a utility function that verifies if a given solution is feasible, and, if not, prints all the validation errors it found. The implementation of this function is completely independent from the implementation of the optimization model, and therefore can be used to validate it. The function can also be used to verify solutions produced by other optimization packages, as long as they follow the [UC.jl data format](format.md).

```julia
using JSON
using UnitCommitment

# Read instance
instance = UnitCommitment.read("instance.json")

# Read solution (potentially produced by other packages) 
solution = JSON.parsefile("solution.json")

# Validate solution and print validation errors
UnitCommitment.validate(instance, solution)
```

## Progressive Hedging

By default, UC.jl uses the Extensive Form (EF) when solving stochastic instances. This approach involves constructing a single JuMP model that contains data and decision variables for all scenarios. Although EF has optimality guarantees and performs well with small test cases, it can become computationally intractable for large instances or substantial number of scenarios.

Progressive Hedging (PH) is an alternative (heuristic) solution method provided by UC.jl in which the problem is decomposed into smaller scenario-based subproblems, which are then solved in parallel in separate Julia processes, potentially across multiple machines. Quadratic penalty terms are used to enforce convergence of first-stage decision variables. The method is closely related to the Alternative Direction Method of Multipliers (ADMM) and can handle larger instances, although it is not guaranteed to converge to the optimal solution. Our implementation of PH relies on Message Passing Interface (MPI) for communication. We refer to [MPI.jl Documentation](https://github.com/JuliaParallel/MPI.jl) for more details on installing MPI.

The following example shows how to solve SCUC instances using progressive hedging. The script should be saved in a file, say `ph.jl`, and executed using `mpiexec -n <num-scenarios> julia ph.jl`.


```julia
using Cbc
using MPI
using UnitCommitment
using Glob

# 1. Initialize MPI
MPI.Init()

# 2. Configure progressive hedging method
ph = UnitCommitment.ProgressiveHedging()

# 3. Read problem instance
instance = UnitCommitment.read(["s1.json", "s2.json"], ph)

# 4. Build JuMP model
model = UnitCommitment.build_model(
    instance = instance,
    optimizer = Cbc.Optimizer,
)

# 5. Run the decentralized optimization algorithm
UnitCommitment.optimize!(model, ph)

# 6. Fetch the solution
solution = UnitCommitment.solution(model, ph)

# 7. Close MPI
MPI.Finalize()
```

When using PH, the model can be customized as usual, with a different formulations or additional user-provided constraints. Note that `read`, in this case, takes `ph` as an argument. This allows each Julia process to read only the instance files that are relevant to it. Similarly, the `solution` function gathers the optimal solution of each processes and returns a combined dictionary. 

Each process solves a sub-problem with $\frac{s}{p}$ scenarios, where $s$ is the total number of scenarios and $p$ is the number of MPI processes. For instance, if we have 15 scenario files and 5 processes, then each process will solve a JuMP model that contains data for 3 scenarios. If the total number of scenarios is not divisible by the number of processes, then an error will be thrown.


!!! warning

    Currently, PH can handle only equiprobable scenarios. Further, `solution(model, ph)` can only handle cases where only one scenario is modeled in each process.

## Benchmarking Solution Methods

The package has a built-in function that serves to compare the performance of the supported solution methods (currently including the extensive form and progressive hedging) in solving different benchmark instances. The following example shows how the built-in `run_ph_benchmark` function can be used to evaluate the performance of the supported solution methods.

```julia
using CSV
using UnitCommitment

# The date of observation used in creating scenarios.
# Can be used to generate scenarios based on different underlying conditions,
# such as different seasons or days of the week.
const DATE = "2017-01-01" 

# A dictionary specifying the test systems used for benchmarking.
# For each test system, SUC models with several scenario numbers can be constructed. 
# For each test system and scenario number, the creation of the scenarios and the 
# solution of the SUC problem can be repeated multiple times, specified by "number of runs".
const BENCHMARK_CASES = Dict(
    "case14" => 
        Dict(
        "scenario numbers" => [4, 6],
        "number of runs" => 3
        ),
    "case118" => 
        Dict(
        "scenario numbers" => [2, 4],
        "number of runs" => 2
        ),
)

# 1. Run benchmark implementations, retrieve the results
benchmark_results = UnitCommitment.run_ph_benchmark(BENCHMARK_CASES, date = DATE)

# 2. Create a data frame that reports the benchmark results in detail
detailed_table = UnitCommitment.fetch_ph_benchmark_detailed_df(benchmark_results)

# 3. Write the data frame to a CSV file
CSV.write("detailed_table.csv", detailed_table)

# 4. Create a data frame that summarizes the benchmark results
summary_table = UnitCommitment.fetch_ph_benchmark_summary_df(benchmark_results)

# 5. Write the data frame to a CSV file
CSV.write("summary_table.csv", summary_table)

```


## Computing Locational Marginal Prices

Locational marginal prices (LMPs) refer to the cost of supplying electricity at a particular location of the network. Multiple methods for computing LMPs have been proposed in the literature. UnitCommitment.jl implements two commonly-used methods: conventional LMPs and Approximated Extended LMPs (AELMPs). To compute LMPs for a given unit commitment instance, the `compute_lmp` function can be used, as shown in the examples below. The function accepts three arguments -- a solved SCUC model, an LMP method, and a linear optimizer -- and it returns a dictionary mapping `(bus_name, time)` to the marginal price.


!!! warning

    Most mixed-integer linear optimizers, such as `HiGHS`, `Gurobi` and `CPLEX` can be used with `compute_lmp`, with the notable exception of `Cbc`, which does not support dual value evaluations. If using `Cbc`, please provide `Clp` as the linear optimizer.

### Conventional LMPs

LMPs are conventionally computed by: (1) solving the SCUC model, (2) fixing all binary variables to their optimal values, and (3) re-solving the resulting linear programming model. In this approach, the LMPs are defined as the dual variables' values associated with the net injection constraints. The example below shows how to compute conventional LMPs for a given unit commitment instance. First, we build and optimize the SCUC model. Then, we call the `compute_lmp` function, providing as the second argument `ConventionalLMP()`.


```julia
using UnitCommitment
using HiGHS

import UnitCommitment: ConventionalLMP

# Read benchmark instance
instance = UnitCommitment.read_benchmark("matpower/case118/2018-01-01")

# Build the model
model = UnitCommitment.build_model(
    instance = instance,
    optimizer = HiGHS.Optimizer,
)

# Optimize the model
UnitCommitment.optimize!(model)

# Compute the LMPs using the conventional method
lmp = UnitCommitment.compute_lmp(
    model,
    ConventionalLMP(),
    optimizer = HiGHS.Optimizer,
)

# Access the LMPs
# Example: "s1" is the scenario name, "b1" is the bus name, 1 is the first time slot
@show lmp["s1","b1", 1]
```

### Approximate Extended LMPs

Approximate Extended LMPs (AELMPs) are an alternative method to calculate locational marginal prices which attemps to minimize uplift payments. The method internally works by modifying the instance data in three ways: (1) it sets the minimum power output of each generator to zero, (2) it averages the start-up cost over the offer blocks for each generator, and (3) it relaxes all integrality constraints. To compute AELMPs, as shown in the example below, we call `compute_lmp` and provide `AELMP()` as the second argument.

This method has two configurable parameters: `allow_offline_participation` and `consider_startup_costs`. If `allow_offline_participation = true`, then offline generators are allowed to participate in the pricing. If instead `allow_offline_participation = false`, offline generators are not allowed and therefore are excluded from the system. A solved UC model is optional if offline participation is allowed, but is required if not allowed. The method forces offline participation to be allowed if the UC model supplied by the user is not solved. For the second field, If `consider_startup_costs = true`, then start-up costs are integrated and averaged over each unit production; otherwise the production costs stay the same. By default, both fields are set to `true`.

!!! warning

    This approximation method is still under active research, and has several limitations. The implementation provided in the package is based on MISO Phase I only. It only supports fast start resources. More specifically, the minimum up/down time of all generators must be 1, the initial power of all generators must be 0, and the initial status of all generators must be negative. The method does not support time-varying start-up costs. The method does not support multiple scenarios. If offline participation is not allowed, AELMPs treats an asset to be  offline if it is never on throughout all time periods. 

```julia
using UnitCommitment
using HiGHS

import UnitCommitment: AELMP

# Read benchmark instance
instance = UnitCommitment.read_benchmark("matpower/case118/2017-02-01")

# Build the model
model = UnitCommitment.build_model(
    instance = instance,
    optimizer = HiGHS.Optimizer,
)

# Optimize the model
UnitCommitment.optimize!(model)

# Compute the AELMPs
aelmp = UnitCommitment.compute_lmp(
    model,
    AELMP(
        allow_offline_participation = false,
        consider_startup_costs = true
    ),
    optimizer = HiGHS.Optimizer
)

# Access the AELMPs
# Example: "s1" is the scenario name, "b1" is the bus name, 1 is the first time slot
# Note: although scenario is supported, the query still keeps the scenario keys for consistency.
@show aelmp["s1", "b1", 1]
```