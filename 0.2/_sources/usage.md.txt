```{sectnum}
---
start: 1
depth: 2
suffix: .
---
```

Usage
=====

Installation
------------

UnitCommitment.jl was tested and developed with [Julia 1.6](https://julialang.org/). To install Julia, please follow the [installation guide on the official Julia website](https://julialang.org/downloads/platform.html). To install UnitCommitment.jl, run the Julia interpreter, type `]` to open the package manager, then type:

```text
pkg> add UnitCommitment@0.2
```

To test that the package has been correctly installed, run:

```text
pkg> test UnitCommitment
```

If all tests pass, the package should now be ready to be used by any Julia script on the machine.

To solve the optimization models, a mixed-integer linear programming (MILP) solver is also required. Please see the [JuMP installation guide](https://jump.dev/JuMP.jl/stable/installation/) for more instructions on installing a solver. Typical open-source choices are [Cbc](https://github.com/JuliaOpt/Cbc.jl) and [GLPK](https://github.com/JuliaOpt/GLPK.jl). In the instructions below, Cbc will be used, but any other MILP solver listed in JuMP installation guide should also be compatible.

Typical Usage
-------------

### Solving user-provided instances

The first step to use UC.jl is to construct a JSON file describing your unit commitment instance. See the [data format page]() for a complete description of the data format UC.jl expects. The next steps, as shown below, are to read the instance from file, construct the optimization model, run the optimization and extract the optimal solution.

```julia
using Cbc
using JSON
using UnitCommitment

# Read instance
instance = UnitCommitment.read("/path/to/input.json")

# Construct optimization model
model = UnitCommitment.build_model(
    instance=instance,
    optimizer=Cbc.Optimizer,
)

# Solve model
UnitCommitment.optimize!(model)

# Extract solution
solution = UnitCommitment.solution(model)

# Write solution to a file
UnitCommitment.write("/path/to/output.json", solution)
```

### Solving benchmark instances

As described in the [Instances page](instances.md), UnitCommitment.jl contains a number of benchmark instances collected from the literature. To solve one of these instances individually, instead of constructing your own, the function `read_benchmark` can be used:

```julia
using UnitCommitment
instance = UnitCommitment.read_benchmark("matpower/case3375wp/2017-02-01")
```

Advanced usage
--------------


### Modifying the formulation

For the time being, the recommended way of modifying the MILP formulation used by UC.jl is to create a local copy of our git repository and directly modify the source code of the package. In a future version, it will be possible to switch between multiple formulations, or to simply add/remove constraints after the model has been generated.

### Generating initial conditions

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
model = UnitCommitment.build_model(instance, Cbc.Optimizer)
UnitCommitment.optimize!(model)
```

```{warning}
The function `generate_initial_conditions!` may return different initial conditions after each call, even if the same instance and the same optimizer is provided. The particular algorithm may also change in a future version of UC.jl. For these reasons, it is recommended that you generate initial conditions exactly once for each instance and store them for later use.
```
    
### Verifying solutions

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
