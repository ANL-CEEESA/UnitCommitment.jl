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

The first step to use UC.jl is to construct a JSON file that describes each scenario of your unit commitment instance. See [Data Format](format.md) for a complete description of the data format UC.jl expects. The next steps, as shown below, are to: (1) construct the instance using scenario files; (2) build the optimization model; (3) run the optimization; and (4) extract the optimal solution. 

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

The above lines of code can also be used for solving the deterministic Security-Constrained Unit Commitment (SCUC) problem, which will create an instance based on a single scenario. The unit commitment instance for SCUC can alternatively be constructed as

```julia
# 1. Read instance
instance = UnitCommitment.read("/path/to/input.json")
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
## Modeling and Solving the SUC Problem

To model the SUC problem, UC.jl supports reading scenario files at a specified directory using the `Glob` package. For instance, in order to construct a SUC instance using all JSON files at a given directory, where each JSON file describes one scenario, the following line of code can be used:

```julia
instance = UnitCommitment.read(glob("*.json", "/path/to/scenarios/"))
```

Alternatively, the specific vector of scenario files can also be passed as follows:
```julia
instance = UnitCommitment.read(["/path/to/s1.json", "/path/to/s2.json"]))
```

## Solving the SUC Problem

We next lay out the alternative methods supported by UC.jl for solving the SUC problem.

## Solving the Extensive Form of the SUC Problem

By default, UC.jl solves the extensive form of the SUC problem. 

```julia
UnitCommitment.optimize!(model)
solution = UnitCommitment.solution(model)
UnitCommitment.write("/path/to/output.json", solution)
```

Note that the created `solution` dictionary will include both the optimal first-stage decisions, as well as the optimal second-stage decisions under all scenarios.

## Solving the SUC Problem Using Progressive Hedging

Importantly, UC.jl further provides the option of solving the SUC problem using the progressive hedging (PH) algorithm, which is an algorithm closely related to the alternating direction method of multipliers (ADMM). To that end, the package supports solving the PH subproblem associated with each scenario in parallel in a separate Julia process, where the communication among the Julia processes is provided using the Message Passing Interface or MPI. 

The solve the SUC problem using Progressive Hedging, you may run the following line of code, which will create `NUM_OF_PROCS` processes where each process executes the `ph.jl` file. 

```julia
using MPI
const FILENAME = "ph.jl"
const NUM_OF_PROCS = 5

mpiexec(exe -> run(`$exe -n $NUM_OF_PROCS $(Base.julia_cmd()) $FILENAME`))
```

#### **`ph.jl`**
```julia
using MPI: MPI_Info
using Gurobi, MPI, UnitCommitment, Glob
import UnitCommitment: ProgressiveHedging

MPI.Init()
ph = ProgressiveHedging.Method()
instance = UnitCommitment.read(
    glob("*.json", "/path/to/scenarios/"),
    ph
)
model = UnitCommitment.build_model(
        instance = instance,
        optimizer = Gurobi.Optimizer,
    )
UnitCommitment.optimize!(model, ph)
solution = UnitCommitment.solution(model, ph)
MPI.Finalize()
```

Observe that the `read`, `build_model`, and `solution` methods take the `ph` object as an argument, which is of type `Progressive Hedging`. 

The subproblem solved within each Julia process deduces the number of scenarios it needs to model using the total number of scenarios and the total number of processes. For instance, if `glob("*.json", "/path/to/scenarios/")` returns a vector of 15 scenario file paths and `NUM_OF_PROCS = 5`, then each subproblem will model and solve 3 scenarios. If the total number of scenarios is not divisible by `NUM_OF_PROCS`, then the read method will throw an error.

The `solution(model, ph)` method gathers the optimal solution of all processes and returns a dictionary that contains all optimal first-stage decisions as well as all optimal second-stage decisions evaluated for each scenario. 

!!! warning

    Currently, PH can handle only equiprobable scenarios. Further, `solution(model, ph)` can only handle cases where only one scenario is modeled in each process.


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