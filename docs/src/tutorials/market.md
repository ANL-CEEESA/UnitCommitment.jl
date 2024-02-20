# Market clearing and LMPs

The UC.jl package offers a comprehensive set of functions for solving marketing problems. The primary function, `solve_market`, facilitates the solution of day-ahead (DA) markets, which can be either deterministic or stochastic in nature. Subsequently, it sequentially maps the commitment status obtained from the DA market to all the real-time (RT) markets, which are deterministic instances. It is essential to ensure that the time span of the DA market encompasses all the RT markets, and the file paths for the RT markets must be specified in chronological order. Each RT market should represent a single time slot, and it is recommended to include a few additional time slots to mitigate the closing window effect.

The `solve_market` function accepts several parameters, including the file path (or a list of file paths in the case of stochastic markets) for the DA market, a list of file paths for the RT markets, the market settings specified by the `MarketSettings` structure, and an optimizer. The `MarketSettings` structure itself requires three optional arguments: `inner_method`, `lmp_method`, and `formulation`. If the computation of Locational Marginal Prices (LMPs) is not desired, the `lmp_method` can be set to `nothing`. Additional optional parameters include a linear programming optimizer for solving LMPs (if a different optimizer than the required one is desired), callback functions `after_build_da` and `after_optimize_da`, which are invoked after the construction and optimization of the DA market, and callback functions `after_build_rt` and `after_optimize_rt`, which are invoked after the construction and optimization of each RT market. It is crucial to note that the `after_build` function requires its two arguments to consistently correspond to `model` and `instance`, while the `after_optimize` function requires its three arguments to consistently correspond to `solution`, `model`, and `instance`.

As an illustrative example, suppose the DA market predicts hourly data for a 24-hour period, while the RT markets represent 5-minute intervals. In this scenario, each RT market file corresponds to a specific 5-minute interval, with the first RT market representing the initial 5 minutes, the second RT market representing the subsequent 5 minutes, and so on. Consequently, there should be 12 RT market files for each hour. To mitigate the closing window effect, except for the last few RT markets, each RT market should contain three time slots, resulting in a total time span of 15 minutes. However, only the first time slot is considered in the final solution. The last two RT markets should only contain 2 and 1 time slot(s), respectively, to ensure that the total time covered by all RT markets does not exceed the time span of the DA market. The code snippet below demonstrates a simplified example of how to utilize the `solve_market` function. Please note that it only serves as a simplified example and may require further customization based on the specific requirements of your use case.

```julia
using UnitCommitment, Cbc, HiGHS

import UnitCommitment:
    MarketSettings,
    XavQiuWanThi2019,
    ConventionalLMP,
    Formulation

solution = UnitCommitment.solve_market(
    "da_instance.json",
    ["rt_instance_1.json", "rt_instance_2.json", "rt_instance_3.json"],
    MarketSettings(
        inner_method = XavQiuWanThi2019.Method(),
        lmp_method = ConventionalLMP(),
        formulation = Formulation(),
    ),
    optimizer = Cbc.Optimizer,
    lp_optimizer = HiGHS.Optimizer,
)
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
