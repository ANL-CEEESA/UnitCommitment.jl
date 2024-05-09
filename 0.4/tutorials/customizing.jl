# # Model customization

# In the previous tutorial, we used UnitCommitment.jl to solve benchmark and user-provided instances using a default mathematical formulation for the problem. In this tutorial, we will explore how to customize this formulation.

# !!! warning

#     This tutorial is not required for using UnitCommitment.jl, unless you plan to make changes to the problem formulation. In this page, we assume familiarity with the JuMP modeling language. Please see [JuMP's official documentation](https://jump.dev/JuMP.jl/stable/) for resources on getting started with JuMP. 

# ## Selecting modeling components

# By default, `UnitCommitment.build_model` uses a formulation that combines modeling components from different publications, and that has been carefully tested, using our own benchmark scripts, to provide good performance across a wide variety of instances. This default formulation is expected to change over time, as new methods are proposed in the literature. You can, however, construct your own formulation, based on the modeling components that you choose, as shown in the next example.

# We start by importing the necessary packages and reading a benchmark instance:

using HiGHS
using JuMP
using UnitCommitment

instance = UnitCommitment.read_benchmark("matpower/case14/2017-01-01");

# Next, instead of calling `UnitCommitment.build_model` with default arguments, we can provide a `UnitCommitment.Formulation` object, which describes what modeling components to use, and how should they be configured. For a complete list of modeling components available in UnitCommitment.jl, see the [API docs](../api.md).

# In the example below, we switch to piecewise-linear cost modeling as defined in [KnuOstWat2018](https://doi.org/10.1109/TPWRS.2017.2783850), as well as ramping and startup costs formulation as defined in [MorLatRam2013](https://doi.org/10.1109/TPWRS.2013.2251373). In addition, we specify custom cutoffs for the shift factors formulation.

model = UnitCommitment.build_model(
    instance = instance,
    optimizer = HiGHS.Optimizer,
    formulation = UnitCommitment.Formulation(
        pwl_costs = UnitCommitment.KnuOstWat2018.PwlCosts(),
        ramping = UnitCommitment.MorLatRam2013.Ramping(),
        startup_costs = UnitCommitment.MorLatRam2013.StartupCosts(),
        transmission = UnitCommitment.ShiftFactorsFormulation(
            isf_cutoff = 0.008,
            lodf_cutoff = 0.003,
        ),
    ),
);

# ## Accessing decision variables

# In the previous tutorial, we saw how to access the optimal solution through `UnitCommitment.solution`. While this approach works well for basic usage, it is also possible to get a direct reference to the JuMP decision variables and query their values, as the next example illustrates.

# First, we load a benchmark instance and solve it, as before.

instance = UnitCommitment.read_benchmark("matpower/case14/2017-01-01");
model = UnitCommitment.build_model(
    instance=instance,
    optimizer=HiGHS.Optimizer,
);
UnitCommitment.optimize!(model)

# At this point, it is possible to obtain a reference to the decision variables by calling `model[:varname][index]`. For example, `model[:is_on]["g1",1]` returns a direct reference to the JuMP variable indicating whether generator named "g1" is on at time 1. For a complete list of decision variables available, and how are they indexed, see the [problem definition](../guides/problem.md).

@show JuMP.value(model[:is_on]["g1",1])

# To access second-stage decisions, it is necessary to specify the scenario name. UnitCommitment.jl models deterministic instances as a particular case in which there is a single scenario named "s1", so we need to use this key.

@show JuMP.value(model[:prod_above]["s1", "g1", 1])

# ## Modifying variables and constraints

# When testing variations of the unit commitment problem, it is often necessary to modify the objective function, variables and constraints of the formulation. UnitCommitment.jl makes this process relatively easy. The first step is to construct the standard model using `UnitCommitment.build_model`:

instance = UnitCommitment.read_benchmark("matpower/case14/2017-01-01");
model = UnitCommitment.build_model(
    instance=instance,
    optimizer=HiGHS.Optimizer,
);

# Now, before calling `UnitCommitment.optimize`, we can make any desired changes to the formulation. In the previous section, we saw how to obtain a direct reference to the decision variables. It is possible to modify them by using standard JuMP methods. For example, to fix the commitment status of a particular generator, we can use `JuMP.fix`:

JuMP.fix(model[:is_on]["g1",1], 1.0, force=true)

# To modify the cost coefficient of a particular variable, we can use `JuMP.set_objective_coefficient`:

JuMP.set_objective_coefficient(
    model,
    model[:switch_on]["g1",1],
    1000.0,
)

# It is also possible to make changes to the set of constraints. For example, we can add a custom constraint, using the `JuMP.@constraint` macro:

@constraint(
    model,
    model[:is_on]["g3",1] + model[:is_on]["g4",1] <= 1,
);

# We can also remove an existing model constraint using `JuMP.delete`. See the [problem definition](../guides/problem.md) for a list of constraint names and indices.

JuMP.delete(model, model[:eq_min_uptime]["g1",1])

# After we are done with all changes, we can call `UnitCommitment.optimize` and extract the optimal solution:

UnitCommitment.optimize!(model)
@show UnitCommitment.solution(model)

# ## Modeling new grid components

# In this section we demonstrate how to add a new grid component to a particular bus in the network. This is useful, for example, when developing formulations for a new type of generator, energy storage, or any other grid device. We start by reading the instance data and buliding a standard model:

instance = UnitCommitment.read_benchmark("matpower/case118/2017-02-01")
model = UnitCommitment.build_model(
    instance=instance,
    optimizer=HiGHS.Optimizer,
);

# Next, we create decision variables for the new grid component. In this example, we assume that the new component can inject up to 10 MW of power at each time step, so we create new continuous variables $0 \leq x_t \leq 10$.

T = instance.time
@variable(model, x[1:T], lower_bound=0.0, upper_bound=10.0);


# Next, we add the production costs to the objective function. In this example, we assume a generation cost of \$5/MW:

for t in 1:T
    set_objective_coefficient(model, x[t], 5.0)
end

# We then attach the new component to bus `b1` by modifying the net injection constraint (`eq_net_injection`):

for t in 1:T
    set_normalized_coefficient(
        model[:eq_net_injection]["s1", "b1", t],
        x[t],
        1.0,
    )
end

# Next, we solve the model:

UnitCommitment.optimize!(model)

# We then finally extract the optimal value of the $x$ variables:

@show value.(x)