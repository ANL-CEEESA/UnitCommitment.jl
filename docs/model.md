```{sectnum}
---
start: 4
depth: 2
suffix: .
---
```

JuMP Model
==========

In this page, we describe the JuMP optimization model produced by the function `UnitCommitment.build_model`. A detailed understanding of this model is not necessary if you are just interested in using the package to solve some standard unit commitment cases, but it may be useful, for example, if you need to solve a slightly different problem, with additional variables and constraints. The notation in this page generally follows [KnOsWa20].

Decision variables
------------------

### Generators

Name | Symbol | Description | Unit
-----|:--------:|-------------|:------:
`is_on[g,t]` | $u_{g}(t)$ | True if generator `g` is on at time `t`. | Binary
`switch_on[g,t]` | $v_{g}(t)$ | True is generator `g` switches on at time `t`. | Binary
`switch_off[g,t]` | $w_{g}(t)$ | True if generator `g` switches off at time `t`. | Binary
`prod_above[g,t]` |$p'_{g}(t)$ | Amount of power produced by generator `g` above its minimum power output at time `t`. For example, if the minimum power of generator `g` is 100 MW and `g` is producing 115 MW of power at time `t`, then `prod_above[g,t]` equals `15.0`. | MW
`segprod[g,t,k]` | $p^k_g(t)$ | Amount of power from piecewise linear segment `k` produced by generator `g` at time `t`. For example, if cost curve for generator `g` is defined by the points `(100, 1400)`, `(110, 1600)`, `(130, 2200)` and `(135, 2400)`, and if the generator is producing 115 MW of power at time `t`, then `segprod[g,t,:]` equals `[10.0, 5.0, 0.0]`.| MW
`reserve[g,t]` | $r_g(t)$ | Amount of reserves provided by generator `g` at time `t`. | MW
`startup[g,t,s]` | $\delta^s_g(t)$ | True if generator `g` switches on at time `t` incurring start-up costs from start-up category `s`. | Binary


### Buses

Name | Symbol | Description | Unit
-----|:------:|-------------|:------:
`net_injection[b,t]` | $n_b(t)$ | Net injection at bus `b` at time `t`. | MW
`curtail[b,t]` | $s^+_b(t)$ | Amount of load curtailed at bus `b` at time `t` | MW


### Price-sensitive loads

Name | Symbol | Description | Unit
-----|:------:|-------------|:------:
`loads[s,t]` | $d_{s}(t)$ | Amount of power served to price-sensitive load `s` at time `t`. | MW

### Transmission lines

Name | Symbol | Description | Unit
-----|:------:|-------------|:------:
`flow[l,t]` | $f_l(t)$ | Power flow on line `l` at time `t`. | MW
`overflow[l,t]` | $f^+_l(t)$ | Amount of flow above the limit for line `l` at time `t`. | MW

```{warning}

Since transmission and N-1 security constraints are enforced in a lazy way, most of the `flow[l,t]` variables are never added to the model. Accessing `model[:flow][l,t]` without first checking that the variable exists will likely generate an error.
```

Objective function
------------------

$$
\begin{align}
    \text{minimize} \;\; &
        \sum_{t \in \mathcal{T}}
          \sum_{g \in \mathcal{G}}
          C^\text{min}_g(t) u_g(t) \\
    &
        + \sum_{t \in \mathcal{T}}
          \sum_{g \in \mathcal{G}}
          \sum_{g \in \mathcal{K}_g}
          C^k_g(t) p^k_g(t) \\
    &
        + \sum_{t \in \mathcal{T}}
          \sum_{g \in \mathcal{G}}
          \sum_{s \in \mathcal{S}_g}
          C^s_{g}(t) \delta^s_g(t) \\
    &
        + \sum_{t \in \mathcal{T}}
          \sum_{l \in \mathcal{L}}
          C^\text{overflow}_{l}(t) f^+_l(t) \\
    &
        + \sum_{t \in \mathcal{T}}
           \sum_{b \in \mathcal{B}}
           C^\text{curtail}(t) s^+_b(t) \\
    &
        - \sum_{t \in \mathcal{T}}
           \sum_{s \in \mathcal{PS}}
           R_{s}(t) d_{s}(t) \\
          
\end{align}
$$
where
- $\mathcal{B}$ is the set of buses
- $\mathcal{G}$ is the set of generators
- $\mathcal{L}$ is the set of transmission lines
- $\mathcal{PS}$ is the set of price-sensitive loads
- $\mathcal{S}_g$ is the set of start-up categories for generator $g$
- $\mathcal{T}$ is the set of time steps
- $C^\text{curtail}(t)$ is the curtailment penalty (in \$/MW)
- $C^\text{min}_g(t)$ is the cost of keeping generator $g$ on and producing at minimum power during time $t$ (in \$)
- $C^\text{overflow}_{l}(t)$ is the flow limit penalty for line $l$ at time $t$ (in \$/MW)
- $C^k_g(t)$ is the cost for generator $g$ to produce 1 MW of power at time $t$ under piecewise linear segment $k$
- $C^s_{g}(t)$ is the cost of starting up generator $g$ at time $t$ under start-up category $s$ (in \$)
- $R_{s}(t)$ is the revenue obtained from serving price-sensitive load $s$ at time $t$ (in \$/MW)


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

### Modifying the model

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

References
----------
* [KnOsWa20] **Bernard Knueven, James Ostrowski and Jean-Paul Watson.** "On Mixed-Integer Programming Formulations for the Unit Commitment Problem". INFORMS Journal on Computing (2020). [DOI: 10.1287/ijoc.2019.0944](https://doi.org/10.1287/ijoc.2019.0944)

