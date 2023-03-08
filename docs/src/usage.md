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

Advanced usage
--------------

### Customizing the formulation

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
model = UnitCommitment.build_model(
    instance=instance,
    optimizer=Cbc.Optimizer,
)
UnitCommitment.optimize!(model)
```

!!! warning

    The function `generate_initial_conditions!` may return different initial conditions after each call, even if the same instance and the same optimizer is provided. The particular algorithm may also change in a future version of UC.jl. For these reasons, it is recommended that you generate initial conditions exactly once for each instance and store them for later use.
    
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

### Computing Locational Marginal Prices (LMPs)

### Conventional LMPs

The locational marginal price (LMP) refers to the cost of withdrawing one additional unit of energy at a bus. UC.jl computes the LMPs of a system using a three-step approach: (1) solving the UC model as usual, (2) fixing the values for all binary variables, and (3) re-solving the model. The LMPs are the dual variables' values associated with the net injection constraints. Step (1) is considered the pre-stage and the model must be solved before calling the `compute_lmp` method, in which Step (2) and (3) take place. 

The `compute_lmp` method calculates the locational marginal prices of the given unit commitment instance. The method accepts 3 arguments, which are(1) a solved UC model, (2) an LMP method object, and (3) a linear optimizer. Note that the LMP method is a struct that inherits the abstract type `PricingMethod`. For conventional (vanilla) LMP, the method is defined under the `LMP` module and contains no fields. Thus, one only needs to specify `LMP.Method()` for the second argument. This particular method style is designed to provide users with more flexibility to design their own pricing calculation methods (see [Approximate Extended LMPs](#approximate-extended-lmps) for more details.) Finally, the last argument requires a linear optimizer. Open-source optimizers such as `Clp` and `HiGHS` can be used here, but solvers such as `Cbc` do not support dual value evaluations and should be avoided in this method. The method returns a dictionary of LMPs. Each key is usually a tuple of "Bus name" and time index. It returns nothing if there is an error in solving the LMPs. Example usage can be found below.

```julia
using UnitCommitment
using Cbc
using HiGHS

import UnitCommitment:
    LMP
    
# Read benchmark instance
instance = UnitCommitment.read("instance.json")

# Construct model (using state-of-the-art defaults)
model = UnitCommitment.build_model(
    instance = instance,
    optimizer = Cbc.Optimizer,
)

# Get the LMPs before solving the UC model
# Error messages will be displayed and the returned value is nothing.
# lmp = UnitCommitment.compute_lmp(model, LMP.Method(), optimizer = HiGHS.Optimizer) # DO NOT RUN

UnitCommitment.optimize!(model)

# Get the LMPs after solving the UC model (the correct way)
# DO NOT use Cbc as the optimizer here. Cbc does not support dual values.
# Compute regular LMP
my_lmp = UnitCommitment.compute_lmp(
    model,
    LMP.Method(),
    optimizer = HiGHS.Optimizer,
)

# Accessing the 'my_lmp' dictionary
# Example: "b1" is the bus name, 1 is the first time slot
@show my_lmp["b1", 1]
```

### Approximate Extended LMPs

UC.jl also provides an alternative method to calculate the approximate extended LMPs (AELMPs). The method is the same as the conventional name `compute_lmp` with the exception that the second argument takes the struct from the `AELMP` module. Similar to the conventional LMP, the AELMP method is a struct that inherits the abstract type `PricingMethod`. The AELMP method is defined under the `AELMP` module and contains two boolean fields: `allow_offline_participation` and `consider_startup_costs`. If `allow_offline_participation = true`, then offline generators are allowed to participate in the pricing. If instead `allow_offline_participation = false`, offline generators are not allowed and therefore are excluded from the system. A solved UC model is optional if offline participation is allowed, but is required if not allowed. The method forces offline participation to be allowed if the UC model supplied by the user is not solved. For the second field, If `consider_startup_costs = true`, then start-up costs are integrated and averaged over each unit production; otherwise the production costs stay the same. By default, both fields are set to `true`. The AELMP method can be used as an example for users to define their own pricing method.

The method calculates the approximate extended locational marginal prices of the given unit commitment instance, which modifies the instance data in 3 ways: (1) it removes the minimum generation requirement for each generator, (2) it averages the start-up cost over the offer blocks for each generator, and (3) it relaxes all the binary constraints and integrality. Similarly, the method returns a dictionary of AELMPs. Each key is usually a tuple of "Bus name" and time index.

However, this approximation method is not fully developed. The implementation is based on MISO Phase I only. It only supports fast start resources. More specifically, the minimum up/down time has to be zero. The method does not support time series of start-up costs. The method can only calculate for the first time slot if offline participation is not allowed. Example usage can be found below.

```julia

using UnitCommitment
using Cbc
using HiGHS

import UnitCommitment:
    AELMP

# Read benchmark instance
instance = UnitCommitment.read("instance.json")

# Construct model (using state-of-the-art defaults)
model = UnitCommitment.build_model(
    instance = instance,
    optimizer = Cbc.Optimizer,
    variable_names = true,
)

# Get the AELMP with the default policy: 
#   1. Offline generators are allowed to participate in pricing
#   2. Start-up costs are considered.
# DO NOT use Cbc as the optimizer here. Cbc does not support dual values.
my_aelmp_default = UnitCommitment.compute_lmp(
    model, # pre-solving is optional if allowing offline participation
    AELMP.Method(),
    optimizer = HiGHS.Optimizer
)

# Get the AELMPs with an alternative policy
#   1. Offline generators are NOT allowed to participate in pricing
#   2. Start-up costs are considered.
# UC model must be solved first if offline generators are NOT allowed
UnitCommitment.optimize!(model)

# then call the AELMP method
my_aelmp_alt = UnitCommitment.compute_lmp(
    model, # pre-solving is required here
    AELMP.Method(
        allow_offline_participation=false,
        consider_startup_costs=true
    ),
    optimizer = HiGHS.Optimizer
)

# Accessing the 'my_aelmp_alt' dictionary
# Example: "b1" is the bus name, 1 is the first time slot
@show my_aelmp_alt["b1", 1]

```