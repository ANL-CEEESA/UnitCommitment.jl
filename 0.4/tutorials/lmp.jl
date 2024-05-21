# # Locational Marginal Prices

# Locational Marginal Prices (LMPs) refer to the cost of supplying electricity at specific locations of the network. LMPs are crucial for the operation of electricity markets and have many other applications, such as indicating what areas of the network may require additional generation or transmission capacity. UnitCommitment.jl implements two methods for calculating LMPS: Conventional LMPs and Approximated Extended LMPs (AELMPs). In this tutorial, we introduce each method and illustrate their usage.

# ### Conventional LMPs

# Conventional LMPs work by (1) solving the original SCUC problem, (2) fixing all binary variables to their optimal values, and (3) re-solving the resulting linear programming model. In this approach, the LMPs are defined as the values of the dual variables associated with the net injection constraints.

# The first step to use this method is to load and optimize an instance, as explained in previous tutorials:

using UnitCommitment
using HiGHS

instance = UnitCommitment.read_benchmark("matpower/case14/2017-01-01")
model =
    UnitCommitment.build_model(instance = instance, optimizer = HiGHS.Optimizer)
UnitCommitment.optimize!(model)

# Next, we call `UnitCommitment.compute_lmp`, as shown below. The function accepts three arguments -- a solved SCUC model, the LMP method, and a linear optimizer -- and it returns a dictionary mapping `(scenario_name, bus_name, time)` to the marginal price.

lmp = UnitCommitment.compute_lmp(
    model,
    UnitCommitment.ConventionalLMP(),
    optimizer = HiGHS.Optimizer,
)

# For example, the following code queries the LMP of bus `b1` in scenario `s1` at time 1:

@show lmp["s1", "b1", 1]

# ### Approximate Extended LMPs

# Approximate Extended LMPs (AELMPs) are an alternative method to calculate locational marginal prices which attemps to minimize uplift payments. The method internally works by modifying the instance data in three ways: (1) it sets the minimum power output of each generator to zero, (2) it averages the start-up cost over the offer blocks for each generator, and (3) it relaxes all integrality constraints. To compute AELMPs, as shown in the example below, we call `compute_lmp` and provide `UnitCommitment.AELMP()` as the second argument.

# This method has two configurable parameters: `allow_offline_participation` and `consider_startup_costs`. If `allow_offline_participation = true`, then offline generators are allowed to participate in the pricing. If instead `allow_offline_participation = false`, offline generators are not allowed and therefore are excluded from the system. A solved UC model is optional if offline participation is allowed, but is required if not allowed. The method forces offline participation to be allowed if the UC model supplied by the user is not solved. For the second field, If `consider_startup_costs = true`, then start-up costs are integrated and averaged over each unit production; otherwise the production costs stay the same. By default, both fields are set to `true`.

# !!! warning

#     This method is still under active research, and has several limitations. The implementation provided in the package is based on MISO Phase I only. It only supports fast start resources. More specifically, the minimum up/down time of all generators must be 1, the initial power of all generators must be 0, and the initial status of all generators must be negative. The method does not support time-varying start-up costs, and only currently works for deterministic instances. If offline participation is not allowed, AELMPs treats an asset to be  offline if it is never on throughout all time periods.

instance = UnitCommitment.read_benchmark("test/aelmp_simple")

model =
    UnitCommitment.build_model(instance = instance, optimizer = HiGHS.Optimizer)

UnitCommitment.optimize!(model)

lmp = UnitCommitment.compute_lmp(
    model,
    UnitCommitment.AELMP(
        allow_offline_participation = false,
        consider_startup_costs = true,
    ),
    optimizer = HiGHS.Optimizer,
)

@show lmp["s1", "B1", 1]
