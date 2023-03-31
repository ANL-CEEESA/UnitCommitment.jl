JuMP Model
==========

In this page, we describe the JuMP optimization model produced by the function `UnitCommitment.build_model`. A detailed understanding of this model is not necessary if you are just interested in using the package to solve some standard unit commitment cases, but it may be useful, for example, if you need to solve a slightly different problem, with additional variables and constraints. The notation in this page generally follows [KnOsWa20].

Decision variables
------------------

### Generators

#### Thermal Units

Name | Symbol | Description | Unit
:-----|:--------:|:-------------|:------:
`is_on[g,t]` | $u_{g}(t)$ | True if generator `g` is on at time `t`. | Binary
`switch_on[g,t]` | $v_{g}(t)$ | True is generator `g` switches on at time `t`. | Binary
`switch_off[g,t]` | $w_{g}(t)$ | True if generator `g` switches off at time `t`. | Binary
`prod_above[g,t]` |$p'_{g}(t)$ | Amount of power produced by generator `g` above its minimum power output at time `t`. For example, if the minimum power of generator `g` is 100 MW and `g` is producing 115 MW of power at time `t`, then `prod_above[g,t]` equals `15.0`. | MW
`segprod[g,t,k]` | $p^k_g(t)$ | Amount of power from piecewise linear segment `k` produced by generator `g` at time `t`. For example, if cost curve for generator `g` is defined by the points `(100, 1400)`, `(110, 1600)`, `(130, 2200)` and `(135, 2400)`, and if the generator is producing 115 MW of power at time `t`, then `segprod[g,t,:]` equals `[10.0, 5.0, 0.0]`.| MW
`reserve[r,g,t]` | $r_g(t)$ | Amount of reserve `r` provided by unit `g` at time `t`. | MW
`startup[g,t,s]` | $\delta^s_g(t)$ | True if generator `g` switches on at time `t` incurring start-up costs from start-up category `s`. | Binary


#### Profiled Units

Name | Symbol | Description | Unit
:-----|:------:|:-------------|:------:
`prod_profiled[s,t]` | $p^{\dagger}_{g}(t)$ | Amount of power produced by profiled unit `g` at time `t`. | MW


### Buses

Name | Symbol | Description | Unit
:-----|:------:|:-------------|:------:
`net_injection[b,t]` | $n_b(t)$ | Net injection at bus `b` at time `t`. | MW
`curtail[b,t]` | $s^+_b(t)$ | Amount of load curtailed at bus `b` at time `t` | MW


### Price-sensitive loads

Name | Symbol | Description | Unit
:-----|:------:|:-------------|:------:
`loads[s,t]` | $d_{s}(t)$ | Amount of power served to price-sensitive load `s` at time `t`. | MW

### Transmission lines

Name | Symbol | Description | Unit
:-----|:------:|:-------------|:------:
`flow[l,t]` | $f_l(t)$ | Power flow on line `l` at time `t`. | MW
`overflow[l,t]` | $f^+_l(t)$ | Amount of flow above the limit for line `l` at time `t`. | MW

!!! warning

    Since transmission and N-1 security constraints are enforced in a lazy way, most of the `flow[l,t]` variables are never added to the model. Accessing `model[:flow][l,t]` without first checking that the variable exists will likely generate an error.

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

Since we now have a direct reference to the JuMP decision variables, it is possible to fix variables, change the coefficients in the objective function, or even add new constraints to the model before solving it. The script below shows how can this be accomplished. For more information on modifying an existing model, [see the JuMP documentation](https://jump.dev/JuMP.jl/stable/manual/variables/).

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

# Fix a decision variable to 1.0
JuMP.fix(
    model[:is_on]["g1",1],
    1.0,
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

    # Attach the new component to bus b1, by modifying the
    # constraint `eq_net_injection`.
    set_normalized_coefficient(
        model[:eq_net_injection]["b1", t],
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

