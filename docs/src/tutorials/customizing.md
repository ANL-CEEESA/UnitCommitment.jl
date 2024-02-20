# Customizing the model

By default, `build_model` uses a formulation that combines modeling components from different publications, and that has been carefully tested, using our own benchmark scripts, to provide good performance across a wide variety of instances. This default formulation is expected to change over time, as new methods are proposed in the literature. You can, however, construct your own formulation, based on the modeling components that you choose, as shown in the next example.

```julia
using HiGHS
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
    optimizer = HiGHS.Optimizer,
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

## Inspecting and modifying the model

### Accessing decision variables

After building a model using `UnitCommitment.build_model`, it is possible to obtain a reference to the decision variables by calling `model[:varname][index]`. For example, `model[:is_on]["g1",1]` returns a direct reference to the JuMP variable indicating whether generator named "g1" is on at time 1. The script below illustrates how to build a model, solve it and display the solution without using the function `UnitCommitment.solution`.

```julia
using Cbc
using Printf
using JuMP
using UnitCommitment

# Load benchmark instance
instance = UnitCommitment.read_benchmark("matpower/case118/2017-02-01")

# Build JuMP model
model = UnitCommitment.build_model(
    instance=instance,
    optimizer=Cbc.Optimizer,
)

# Solve the model
UnitCommitment.optimize!(model)

# Display commitment status
for g in instance.units
    for t in 1:instance.time
        @printf(
            "%-10s %5d %5.1f %5.1f %5.1f\n",
            g.name,
            t,
            value(model[:is_on][g.name, t]),
            value(model[:switch_on][g.name, t]),
            value(model[:switch_off][g.name, t]),
        )
    end
end
```

### Fixing variables, modifying objective function and adding constraints

Since we now have a direct reference to the JuMP decision variables, it is possible to fix variables, change the coefficients in the objective function, or even add new constraints to the model before solving it.
!!! warning

    It is important to take into account the stage of the decision variables in modifying the optimization model. In changing a deterministic SCUC model, modifying the second-stage decision variables requires adding the term `s1`, which is the default scenario name assigned to the second-stage decision variables in the SCUC model. For an SUC model, the package permits the modification of the second-stage decision variables individually for each scenario.

The script below shows how the JuMP model can be modified after it is created. For more information on modifying an existing model, [see the JuMP documentation](https://jump.dev/JuMP.jl/stable/manual/variables/).

```julia
using Cbc
using JuMP
using UnitCommitment

# Load benchmark instance
instance = UnitCommitment.read_benchmark("matpower/case118/2017-02-01")

# Construct JuMP model
model = UnitCommitment.build_model(
    instance=instance,
    optimizer=Cbc.Optimizer,
)

# Fix the commitment status of the generator "g1" in time period 1 to 1.0
JuMP.fix(
    model[:is_on]["g1",1],
    1.0,
    force=true,
)

# Fix the production level of the generator "g1" above its minimum level in time period 1 and
# in scenario "s1" to 20.0 MW. Observe that the three-tuple dictionary key involves the scenario
# index "s1", as production above minimum is a second-stage decision variable.
JuMP.fix(
    model[:prod_above]["s1", "g1", 1],
    20.0,
    force=true,
)

# Enforce the curtailment of 20.0 MW of load at bus "b2" in time period 4 in scenario "s1".
JuMP.fix(
    curtail["s1", "b2", 4] =
    20.0,
    force=true,
)

# Change the objective function
JuMP.set_objective_coefficient(
    model,
    model[:switch_on]["g2",1],
    1000.0,
)

# Create a new constraint
@constraint(
    model,
    model[:is_on]["g3",1] + model[:is_on]["g4",1] <= 1,
)

# Solve the model
UnitCommitment.optimize!(model)
```

### Adding new component to a bus

The following snippet shows how to add a new grid component to a particular bus. For each time step, we create decision variables for the new grid component, add these variables to the objective function, then attach the component to a particular bus by modifying some existing model constraints.

```julia
using Cbc
using JuMP
using UnitCommitment

# Load instance and build base model
instance = UnitCommitment.read_benchmark("matpower/case118/2017-02-01")
model = UnitCommitment.build_model(
    instance=instance,
    optimizer=Cbc.Optimizer,
)

# Get the number of time steps in the original instance
T = instance.time

# Create decision variables for the new grid component.
# In this example, we assume that the new component can
# inject up to 10 MW of power at each time step, so we
# create new continuous variables 0 ≤ x[t] ≤ 10.
@variable(model, x[1:T], lower_bound=0.0, upper_bound=10.0)

# For each time step
for t in 1:T

    # Add production costs to the objective function.
    # In this example, we assume a cost of $5/MW.
    set_objective_coefficient(model, x[t], 5.0)

    # Attach the new component to bus b1 in scenario s1, by modifying the
    # constraint `eq_net_injection`.
    set_normalized_coefficient(
        model[:eq_net_injection]["s1", "b1", t],
        x[t],
        1.0,
    )
end

# Solve the model
UnitCommitment.optimize!(model)

# Show optimal values for the x variables
@show value.(x)
```
