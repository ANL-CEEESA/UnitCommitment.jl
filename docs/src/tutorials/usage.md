# Getting started

## Installation

UnitCommitment.jl was tested and developed with [Julia 1.9](https://julialang.org/). To install Julia, please follow the [installation guide on the official Julia website](https://julialang.org/downloads/). To install UnitCommitment.jl, run the Julia interpreter, type `]` to open the package manager, then type:

```text
pkg> add UnitCommitment@0.4
```

To solve the optimization models, a mixed-integer linear programming (MILP) solver is also required. Please see the [JuMP installation guide](https://jump.dev/JuMP.jl/stable/installation/) for more instructions on installing a solver. Typical open-source choices are [HiGHS](https://github.com/jump-dev/HiGHS.jl), [Cbc](https://github.com/JuliaOpt/Cbc.jl) and [GLPK](https://github.com/JuliaOpt/GLPK.jl). In the instructions below, HiGHS will be used, but any other MILP solver listed in JuMP installation guide should also be compatible.

## Solving user-provided instances

The first step to use UC.jl is to construct JSON files that describe each scenario of your deterministic or stochastic unit commitment instance. See [Data Format](../guides/format.md) for a complete description of the data format UC.jl expects. The next steps, as shown below, are to: (1) read the scenario files; (2) build the optimization model; (3) run the optimization; and (4) extract the optimal solution.

```julia
using HiGHS
using JuMP
using UnitCommitment

# 1. Read instance
instance = UnitCommitment.read(["example/s1.json", "example/s2.json"])

# 2. Construct optimization model
model = UnitCommitment.build_model(
    instance=instance,
    optimizer=HiGHS.Optimizer,
)

# 3. Solve model
UnitCommitment.optimize!(model)

# 4. Write solution to a file
solution = UnitCommitment.solution(model)
UnitCommitment.write("example/out.json", solution)
```

To read multiple files from a given folder, the [Glob](https://github.com/vtjnash/Glob.jl) package can be used:

```jldoctest usage1; output = false
using Glob
using UnitCommitment

instance = UnitCommitment.read(glob("s*.json", "example/"))

# output
UnitCommitmentInstance(2 scenarios, 6 thermal units, 0 profiled units, 14 buses, 20 lines, 19 contingencies, 1 price sensitive loads, 4 time steps)
```

To solve deterministic instances, a single scenario file may be provided.

```jldoctest usage1; output = false
instance = UnitCommitment.read("example/s1.json")

# output
UnitCommitmentInstance(1 scenarios, 6 thermal units, 0 profiled units, 14 buses, 20 lines, 19 contingencies, 1 price sensitive loads, 4 time steps)
```

## Solving benchmark instances

UnitCommitment.jl contains a large number of deterministic benchmark instances collected from the literature and converted into a common data format. To solve one of these instances individually, instead of constructing your own, the function `read_benchmark` can be used, as shown below. See [Instances](../guides/instances.md) for the complete list of available instances.

```jldoctest usage1; output = false
instance = UnitCommitment.read_benchmark("matpower/case3375wp/2017-02-01")

# output
UnitCommitmentInstance(1 scenarios, 590 thermal units, 0 profiled units, 3374 buses, 4161 lines, 3245 contingencies, 0 price sensitive loads, 36 time steps)
```

## Generating initial conditions

When creating random unit commitment instances for benchmark purposes, it is often hard to compute, in advance, sensible initial conditions for all thermal generators. Setting initial conditions naively (for example, making all generators initially off and producing no power) can easily cause the instance to become infeasible due to excessive ramping. Initial conditions can also make it hard to modify existing instances. For example, increasing the system load without carefully modifying the initial conditions may make the problem infeasible or unrealistically challenging to solve.

To help with this issue, UC.jl provides a utility function which can generate feasible initial conditions by solving a single-period optimization problem, as shown below:

```julia
using HiGHS
using UnitCommitment

# Read original instance
instance = UnitCommitment.read("example/s1.json")

# Generate initial conditions (in-place)
UnitCommitment.generate_initial_conditions!(instance, HiGHS.Optimizer)

# Construct and solve optimization model
model = UnitCommitment.build_model(
    instance=instance,
    optimizer=HiGHS.Optimizer,
)
UnitCommitment.optimize!(model)
```

!!! warning

    The function `generate_initial_conditions!` may return different initial conditions after each call, even if the same instance and the same optimizer is provided. The particular algorithm may also change in a future version of UC.jl. For these reasons, it is recommended that you generate initial conditions exactly once for each instance and store them for later use.

## Verifying solutions

When developing new formulations, it is very easy to introduce subtle errors in the model that result in incorrect solutions. To help avoiding this, UC.jl includes a utility function that verifies if a given solution is feasible, and, if not, prints all the validation errors it found. The implementation of this function is completely independent from the implementation of the optimization model, and therefore can be used to validate it.

```jldoctest; output = false
using JSON
using UnitCommitment

# Read instance
instance = UnitCommitment.read("example/s1.json")

# Read solution (potentially produced by other packages)
solution = JSON.parsefile("example/out.json")

# Validate solution and print validation errors
UnitCommitment.validate(instance, solution)

# output

true
```
