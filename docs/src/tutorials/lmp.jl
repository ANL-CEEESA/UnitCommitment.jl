# # Locational Marginal Prices

# Locational Marginal Prices (LMPs) refer to the cost of supplying electricity at specific locations of the network. LMPs are crucial for the operation of electricity markets and have many other applications, such as indicating what areas of the network may require additional generation or transmission capacity. UnitCommitment.jl implements two methods for calculating LMPS: Conventional LMPs and Approximated Extended LMPs (AELMPs). Both methods are implemented as extensions that integrate seamlessly into the optimization pipeline. In this tutorial, we introduce each method and illustrate their usage.

# ### Conventional LMPs

# Conventional LMPs work by (1) solving the original SCUC problem, (2) fixing all binary variables to their optimal values, and (3) re-solving the resulting linear programming model. In this approach, the LMPs are defined as the values of the dual variables associated with the net injection constraints.

# To use this method, we load an instance and register the `ConventionalLMP` extension. Extensions are passed via the `extensions` keyword argument when reading the instance. Once registered, the LMP computation is automatically performed during the optimization step.

using UnitCommitment
using HiGHS

instance = UnitCommitment.read_benchmark(
    "matpower/case14/2017-01-01",
    extensions = [
        UnitCommitment.ConventionalLMP(),
    ],
)
model =
    UnitCommitment.build_model(instance = instance, optimizer = HiGHS.Optimizer)
UnitCommitment.optimize!(model)

# After optimization, LMPs are included in the solution dictionary. We can access them as follows:

solution = UnitCommitment.solution(model)
lmp = solution["Locational marginal price (\$/MWh)"]

# For example, the following code queries the LMP of bus `b1` at time 1:

@show lmp["b1", 1]

# ### Approximate Extended LMPs

# Approximate Extended LMPs (AELMPs) are an alternative method to calculate locational marginal prices which attemps to minimize uplift payments. The method internally works by modifying the instance data in three ways: (1) it sets the minimum power output of each generator to zero, (2) it averages the start-up cost over the offer blocks for each generator, and (3) it relaxes all integrality constraints. To compute AELMPs, we register the `AELMP` extension with the instance.

# The `AELMP` extension takes three arguments: `allow_offline_participation`, `consider_startup_costs`, and `optimizer`. If `allow_offline_participation` is `true`, then offline generators are allowed to participate in the pricing. If instead it is `false`, offline generators are excluded from the system, and a solved UC model is required. If `consider_startup_costs` is `true`, then start-up costs are integrated and averaged over each unit production; otherwise the production costs stay the same. The `optimizer` argument specifies the optimizer used to solve the LP relaxation problem.

# !!! warning

#     This method is still under active research, and has several limitations. The implementation provided in the package is based on MISO Phase I only. It only supports fast start resources. More specifically, the minimum up/down time of all generators must be 1, the initial power of all generators must be 0, and the initial status of all generators must be negative. The method does not support time-varying start-up costs, and only currently works for deterministic instances. If offline participation is not allowed, AELMPs treats an asset to be  offline if it is never on throughout all time periods.

instance = UnitCommitment.read_benchmark(
    "test/aelmp_simple",
    extensions = [
        UnitCommitment.AELMP(
            allow_offline_participation = false,
            consider_startup_costs = true,
            optimizer = HiGHS.Optimizer,
        ),
    ],
)

model =
    UnitCommitment.build_model(instance = instance, optimizer = HiGHS.Optimizer)

UnitCommitment.optimize!(model)

solution = UnitCommitment.solution(model)
lmp = solution["Locational marginal price (\$/MWh)"]

@show lmp["B1", 1]
