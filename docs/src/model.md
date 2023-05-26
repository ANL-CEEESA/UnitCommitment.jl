JuMP Model
==========

In this page, we describe the JuMP optimization model produced by the function `build_model`. A detailed understanding of this model is not necessary if you are just interested in using the package to solve some standard unit commitment cases, but it may be useful, for example, if you need to solve a slightly different problem, with additional variables and constraints. The notation in this page generally follows [KnOsWa20].

Decision variables
------------------

UC.jl models the security-constrained unit commitment problem as a two-stage stochastic program. In this approach, some of the decision variables are *first-stage decisions*, which are taken before the uncertainty is realized and must therefore be the same across all scenarios, while the remaining variables are *second-stage decisions*, which can attain a different values in each scenario. In the current version of the package, all binary variables (which model commitment decisions of thermal units) are first-stage decisions and all continuous variables are second-stage decisions.

!!! note

    UC.jl treats deterministic SCUC instances as a special case of the stochastic problem in which there is only one scenario, named `"s1"` by default. To access second-stage decisions, therefore, you must provide this scenario name as the value for `sn`. For example, `model[:prod_above]["s1", g, t]`. 

### Generators

In this section, we describe the decision variables associated with the generators, which include both thermal units (e.g., natural gas-fired power plant) and profiled units (e.g., wind turbine). 

#### Thermal Units

Name |  Description | Unit | Stage
:-----|:-------------|:------: | :------:
`is_on[g,t]` | True if generator `g` is on at time `t`. | Binary | 1
`switch_on[g,t]` | True is generator `g` switches on at time `t`. | Binary| 1
`switch_off[g,t]` | True if generator `g` switches off at time `t`. | Binary| 1
`startup[g,t,s]` | True if generator `g` switches on at time `t` incurring start-up costs from start-up category `s`. | Binary| 1
`prod_above[sn,g,t]` | Amount of power produced by generator `g` above its minimum power output at time `t` in scenario `sn`. For example, if the minimum power of generator `g` is 100 MW and `g` is producing 115 MW of power at time `t` in scenario `sn`, then `prod_above[sn,g,t]` equals `15.0`. | MW | 2
`segprod[sn,g,t,k]` | Amount of power from piecewise linear segment `k` produced by generator `g` at time `t` in scenario `sn`. For example, if cost curve for generator `g` is defined by the points `(100, 1400)`, `(110, 1600)`, `(130, 2200)` and `(135, 2400)`, and if the generator is producing 115 MW of power at time `t` in scenario `sn`, then `segprod[sn,g,t,:]` equals `[10.0, 5.0, 0.0]`.| MW | 2
`reserve[sn,r,g,t]` | Amount of reserve `r` provided by unit `g` at time `t` in scenario `sn`. | MW | 2

!!! warning

    The first-stage decision variables of the JuMP model are `is_on[g,t]`, `switch_on[g,t]`, `switch_off[g,t]`, and `startup[g,t,s]`. As such, the dictionaries corresponding to these variables do not include the scenario index in their keys. In contrast, all other variables of the created JuMP model are allowed to obtain a different value in each scenario and are thus modeled as second-stage decision variables. Accordingly, the dictionaries of all second-stage decision variables have the scenario index in their keys. This is true even if the model is created to solve the deterministic SCUC, in which case the default scenario index `s1` is included in the dictionary key.
    

#### Profiled Units

Name | Description | Unit | Stage
:-----|:-------------|:------: | :------:
`prod_profiled[s,t]` | Amount of power produced by profiled unit `g` at time `t`. | MW | 2


### Buses

Name | Description | Unit | Stage
:-----|:-------------|:------:| :------:
`net_injection[sn,b,t]` | Net injection at bus `b` at time `t` in scenario `sn`. | MW | 2
`curtail[sn,b,t]` | Amount of load curtailed at bus `b` at time `t` in scenario `sn`. | MW | 2


### Price-sensitive loads

Name |  Description | Unit | Stage
:-----|:-------------|:------:| :------:
`loads[sn,s,t]` | Amount of power served to price-sensitive load `s` at time `t` in scenario `sn`. | MW | 2

### Transmission lines

Name |  Description | Unit | Stage 
:-----|:-------------|:------:| :------:
`flow[sn,l,t]` |  Power flow on line `l` at time `t` in scenario `sn`. | MW | 2
`overflow[sn,l,t]` | Amount of flow above the limit for line `l` at time `t` in scenario `sn`. | MW | 2

!!! warning

    Since transmission and N-1 security constraints are enforced in a lazy way, most of the `flow[l,t]` variables are never added to the model. Accessing `model[:flow][sn,l,t]` without first checking that the variable exists will likely generate an error.

Objective function
------------------

TODO

Constraints
-----------

TODO


Inspecting and modifying the model
----------------------------------

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

References
----------
* [KnOsWa20] **Bernard Knueven, James Ostrowski and Jean-Paul Watson.** "On Mixed-Integer Programming Formulations for the Unit Commitment Problem". INFORMS Journal on Computing (2020). [DOI: 10.1287/ijoc.2019.0944](https://doi.org/10.1287/ijoc.2019.0944)

