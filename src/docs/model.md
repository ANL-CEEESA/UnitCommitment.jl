Benchmark Model
===============

UnitCommitment.jl includes a reference Mixed-Integer Linear Programming
(MILP), built with [JuMP](https://github.com/JuliaOpt/JuMP.jl), which can
either be used as-is to solve instances of the problem, or be extended to
build more complex formulations.

Building and Solving the Model
-------------------------------

Given an instance and a JuMP optimizer, the function `build_model` can be used to
build the reference MILP model. For example:

```julia
using UnitCommitment, JuMP, Cbc
instance = UnitCommitment.load("ieee_rts/case118")
model = build_model(instance, with_optimizer(Cbc.Optimizer))
```

The model enforces all unit constraints described in [Unit Commitment
Instances](@ref), including ramping, minimum-up and minimum-down times. Some
system-wide constraints, such as spinning reserves, are also enforced. The
model, however, does not enforce transmission or N-1 security constraints,
since these are typically generated on-the-fly.

A reference to the JuMP model is stored at `model.mip`. After constructed, the model can
be optimized as follows:

```julia
optimize!(model.mip)
```

Decision Variables
------------------

References to all decision variables are stored at `model.vars`.
A complete list of available decision variables is as follows:

| Variable                      | Description
| :---------------------------- | :---------------------------
| `model.vars.production[gi,t]`        | Amount of power (in MW) produced by unit with index `gi` at time `t`.
| `model.vars.reserve[gi,t]`           | Amount of spinning reserves (in MW) provided by unit with index `gi` at time `t`.
| `model.vars.is_on[gi,t]`             | Binary variable indicating if unit with index `gi` is operational at time `t`.
| `model.vars.switch_on[gi,t]`         | Binary variable indicating if unit with index `gi` was switched on at time `t`. That is, the unit was not operational at time `t-1`, but it is operational at time `t`.
| `model.vars.switch_off[gi,t]`        | Binary variable indicating if unit with index `gi` was switched off at time `t`. That is, the unit was operational at time `t-1`, but it is no longer operational at time `t`.
| `model.vars.unit_cost[gi,t]`         | The total cost to operate unit with index `gi` at time `t`. Includes start-up costs, no-load costs and any other production costs.
| `model.vars.cost[t]`                | Total cost at time `t`.
| `model.vars.net_injection[bi,t]`     | Total net injection (in MW) at bus with index `bi` and time `t`. Net injection is defined as the total power being produced by units located at the bus minus the bus load.


Accessing the Solution
----------------------
To access the value of a particular decision variable after the
optimization is completed, the function `JuMP.value(var)` can be used. The
following example prints the amount of power (in MW) produced by each unit at time 5:

```julia
for g in instance.units
    @show value(model.vars.production[g.index, 5])
end
```

Modifying the Model
-------------------

Prior to being solved, the reference model can be modified by using the variable references
above and conventional JuMP macros. For example, the
following code can be used to ensure that at most 10 units are operational at time 4:

```julia
using UnitCommitment, JuMP, Cbc
instance = UnitCommitment.load("ieee_rts/case118")
model = build_model(instance, with_optimizer(Cbc.Optimizer))

@contraint(model.mip,
           sum(model.vars.is_on[g.index, 4]
               for g in instance.units) <= 10)

optimize!(model.mip)
```

It is not currently possible to modify the constraints included in the
reference model.

Reference
---------
```@docs
UnitCommitment.build_model
```