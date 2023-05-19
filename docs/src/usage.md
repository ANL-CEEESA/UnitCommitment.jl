Usage
=====

Installation
------------

UnitCommitment.jl was tested and developed with [Julia 1.7](https://julialang.org/). To install Julia, please follow the [installation guide on the official Julia website](https://julialang.org/downloads/). To install UnitCommitment.jl, run the Julia interpreter, type `]` to open the package manager, then type:

```text
pkg> add UnitCommitment@0.3
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

The first step to use UC.jl is to construct a JSON file describing your unit commitment instance. See [Data Format](format.md) for a complete description of the data format UC.jl expects. The next steps, as shown below, are to: (1) read the instance from file; (2) construct the optimization model; (3) run the optimization; and (4) extract the optimal solution.

```julia
using Cbc
using JSON
using UnitCommitment

# 1. Read instance
instance = UnitCommitment.read("/path/to/input.json")

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

### Solving benchmark instances

UnitCommitment.jl contains a large number of benchmark instances collected from the literature and converted into a common data format. To solve one of these instances individually, instead of constructing your own, the function `read_benchmark` can be used, as shown below. See [Instances](instances.md) for the complete list of available instances.

```julia
using UnitCommitment
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

## Time Decomposition Method

When solving a unit commitment instance with a dense time slot structure, computational complexity can become a significant challenge. For instance, if the instance contains hourly data for an entire year (8760 hours), solving such a model can require a substantial amount of computational power. To address this issue, UC.jl provides a time_decomposition method within the `optimize!` function. This method decomposes the problem into multiple sub-problems, solving them sequentially.

The `optimize!` function takes three parameters: a unit commitment instance, a `TimeDecomposition` method, and an optimizer. It returns a solution dictionary. The `TimeDecomposition` method itself requires four arguments: `time_window`, `time_increment`, `inner_method`, and `formulation`. These arguments define the time window for each sub-problem, the time increment to move to the next sub-problem, the method used to solve each sub-problem, and the formulation employed, respectively.

The code snippet below illustrates an example of solving an instance by decomposing the model into multiple 36-hour sub-problems using the `XavQiuWanThi2019` method. Each sub-problem advances 24 hours at a time. The first sub-problem covers time steps 1 to 36, the second covers time steps 25 to 60, the third covers time steps 49 to 84, and so on. The initial power levels and statuses of the second and subsequent sub-problems are set based on the results of the first 24 hours from each of their immediate prior sub-problems. In essence, this approach addresses the complexity of solving a large problem by tackling it in 24-hour intervals, while incorporating an additional 12-hour buffer to mitigate the closing window effect for each sub-problem.

!!! warning

    Specifying `TimeDecomposition` as the value of the `inner_method` field of another `TimeDecomposition` causes errors when calling the `optimize!` function due to the different argument structures between the two `optimize!` functions.


```julia
using UnitCommitment, Cbc

import UnitCommitment: 
    TimeDecomposition,
    Formulation,
    XavQiuWanThi2019

instance = UnitCommitment.read("instance.json")

solution = UnitCommitment.optimize!(
    instance,
    TimeDecomposition(
        time_window = 36,  # solve 36h problems
        time_increment = 24,  # advance by 24h each time
        inner_method = XavQiuWanThi2019.Method(),
        formulation = Formulation(),
    ),
    optimizer=Cbc.Optimizer
)
```