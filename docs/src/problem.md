# Problem Definition

The **Security-Constrained Unit Commitment Problem** (SCUC) is a two-stage stochastic mixed-integer linear optimization problem that aims to find the minimum-cost schedule for electricity generation while satisfying various physical, operational and economic constraints. In its most basic form, the problem is composed by:

- A set of thermal generators, which produce power, at a given cost;
- A set of loads, which consume power;
- A transmission network, which delivers power from generators to the loads.

In addition to the basic components above, modern versions of SCUC also include a wide variety of additional components, such as _energy storage devices_, _reserves_, _price-sensitive loads_ and _network interfaces_, to name a few. On this page, we present a complete definition of the problem as it is formulated in UC.jl. Please note that various souces in the literature may have different definitions.

## General modeling assumptions

SCUC is a multi-period problem, with decisions typically covering a 24-hour or 36-hour time window. UC.jl assumes that this time window is discretized into time steps of fixed length. The number of time steps, as well as the duration of each time step, are configurable. In the equations below, the set of time steps is denoted by $T=\{1,2,\ldots,|T|\}$.

SCUC is also a two-stage stochastic problem. In the first stage, we must decide the _commitment status_ of all thermal generators. In the second stage, we determine the remaining decision variables, such power output of all generators, the operation of energy storage devices and load shedding. Stochasticity is modeled through a discrete number of scenarios $s \in S$, each with given probability $p(S)$. The goal is to minimize the minimum expected cost. The deterministic version of SCUC can be modeled by assuming a single scenario with probability 1.

## Thermal Generators

A _thermal generator_ is a power generation unit that converts thermal energy, typically from the combustion of coal, natural gas or oil, into electrical energy. Scheduling thermal generators is particularly complex due to their operational characteristics, including minimum up and down times, ramping rates, and start-up and shutdown limits.

### Concepts

- **Commitment, power output and startup costs:** Thermal generators can either be operational (on) or offline (off). When a thermal generator is on, it can produce between a minimum and a maximum amount of power; when it is off, it cannot produce any power. Switching a generator on incurs a startup cost, which depends on how long the unit has been offline. More precisely, each thermal generator $g$ has a number $K^{start}_g$ of startup categories (e.g., cold, warm and hot). Each category $k$ has a corresponding startup cost $Z^{\text{start}}_{gk}$, and is available only if the unit has spent at most $M^{\text{delay}}_{gk}$ time steps offline.

- **Piecewise-linear production cost curve:** Besides startup costs, thermal generators also incur production costs based on their power output. The relationship between production cost and power output is not a linear, but a convex curve, which is simplified using a piecewise-linear approximation. For this purpose, each thermal generator $g$ has a number $K^{\text{cost}}_g$ of piecewise-linear segments and its power output $y^{\text{prod-above}}_{gts}$ are broken down into $\sum_{k=1}^{K^{\text{cost}}_g} y^{\text{seg-prod}}_{gtks}$, so that production costs can be more easily calculated.

- **Ramping, minimum up/down:** Due to physical and operational limits, such as thermal inertia and mechanical stress, thermal generators cannot vary their power output too dramatically from one time period to the next. Similarly, thermal generators cannot switch on and off too frequently; after switching on or off, units must remain at that state for a minimum specified number of time steps.

- **Initial status:** The optimization process finds optimal commitment status and power output level for all thermal generators starting at time period 1. Many constraints, however, require knowledge of previous time periods (0, -1, -2, ...) which are not part of the optimization model. For this reason, part of the input data is the initial power output $M^{\text{init-power}}_{g}$ of unit $g$ (that is, the output at time 0) and the initial status $M^{\text{init-status}}_{g}$ of unit g (how many time steps has it been online/offline at time time 0). If $M^{\text{init-status}}_{g}$ is positive, its magnitude indicates how many time periods has the unit been online; and if negative, how has it been offline.

- **Must-run:** Due to various factors, including reliability considerations, some units must remain operational regardless of whether it is economical for them to do so. Must-run constraints are used to enforce such requirements.

### Sets and constants

| Symbol                       | Unit   | Description                                                                                |
| :--------------------------- | :----- | :----------------------------------------------------------------------------------------- |
| $K^{cost}_g$                 |        | Number of piecewise linear segments in the production cost curve.                          |
| $K^{start}_g$                |        | Number of startup categories (e.g. cold, warm, hot).                                       |
| $M^{\text{delay}}_{gk}$      |        | Delay for startup category $k$.                                                            |
| $M^{\text{init-power}}_{g}$  | MW     | Initial power output of unit $g$.                                                          |
| $M^{\text{init-status}}_{g}$ |        | Initial status of unit $g$.                                                                |
| $M^{\text{min-up}}_{g}$      |        | Minimum amount of time $g$ must stay on after switching on.                                |
| $M^{\text{must-run}}_{gt}$   | Binary | One if unit $g$ must be on at time $t$.                                                    |
| $M^{\text{pmax}}_{gt}$       | MW     | Maximum power output at time $t$.                                                          |
| $M^{\text{pmin}}_{gt}$       | MW     | Minimum power output at time $t$.                                                          |
| $M^{\text{ramp-down}}_{g}$   | MW     | Ramp down limit.                                                                           |
| $M^{\text{ramp-up}}_{g}$     | MW     | Ramp up limit.                                                                             |
| $R_g$                        |        | Set of spinning reserves that may be served by $g$.                                        |
| $Z^{\text{pmin}}_{gt}$       | \$     | Cost to keep $g$ operational at time $t$ generating at minimum power.                      |
| $Z^{\text{pvar}}_{gtks}$     | \$/MW  | Cost for unit $g$ to produce 1 MW of power under piecewise-linear segment $k$ at time $t$. |
| $Z^{\text{start}}_{gk}$      | \$     | Cost to start unit $g$ at startup category $k$.                                            |

### Decision variables

| Symbol                        | Description                                                                                   | Unit   | Stage |
| :---------------------------- | :-------------------------------------------------------------------------------------------- | :----- | :---- |
| $x^{\text{is-on}}_{gt}$       | One if generator $g$ is on at time $t$.                                                       | Binary | 1     |
| $x^{\text{switch-on}}_{gt}$   | One if generator $g$ switches on at time $t$.                                                 | Binary | 1     |
| $x^{\text{switch-off}}_{gt}$  | One if generator $g$ switches off at time $t$.                                                | Binary | 1     |
| $x^{\text{start}}_{gtk}$      | One if generator $g$ starts up at time $t$ under startup category $k$.                        | Binary | 1     |
| $y^{\text{prod-above}}_{gts}$ | Amount of power produced by $g$ at time $t$ in scenario $s$ above the minimum power.          | MW     | 2     |
| $y^{\text{seg-prod}}_{gtks}$  | Amount of power produced by $g$ at time $t$ in piecewise-linear segment $k$ and scenario $s$. | MW     | 2     |
| $y^{\text{res}}_{grts}$       | Amount of spinning reserve $r$ supplied by $g$ at time $t$ in scenario $s$.                   | MW     | 2     |

### Objective function terms

- Production costs:

```math
\sum_{g \in G} \sum_{t \in T} x^{\text{is-on}}_{gt} Z^{\text{pmin}}_{gt}
+ \sum_{s \in S} p(s) \left[
    \sum_{g \in G} \sum_{t \in T} \sum_{k=1}^{K^{cost}_g}
    y^{\text{seg-prod}}_{gtks} Z^{\text{pvar}}_{gtks}
\right]
```

- Start-up costs:

```math
\sum_{g \in G} \sum_{t \in T} \sum_{k=1}^{K^{start}_g} x^{\text{start}}_{gtk} Z^{\text{start}}_{gk}
```

### Constraints

- Some units must remain on, even if it is not economical for them to do so:

```math
x^{\text{is-on}}_{gt} \geq M^{\text{must-run}}_{gt}
```

- After switching on, unit must remain on for some amount of time:

```math
\sum_{i=max(1,t-M^{\text{min-up}}_{g}+1)}^t x^{\text{switch-on}}_{gi} \leq x^{\text{is-on}}_{gt}
```

- Same as above, but covering the initial time steps:

```math
\sum_{i=1}^{min(T,M^{\text{min-up}}_{g}-M^{\text{init-status}}_{g})} x^{\text{switch-off}}_{gi} = 0 \; \text{ if } \; M^{\text{init-status}}_{g} > 0
```

- After switching off, unit must remain offline for some amount of time:

```math
\sum_{i=max(1,t-M^{\text{min-down}}_{g}+1)}^t x^{\text{switch-off}}_{gi} \leq 1 - x^{\text{is-on}}_{gt}
```

- Same as above, but covering the initial time steps:

```math
\sum_{i=1}^{min(T,M^{\text{min-down}}_{g}+M^{\text{init-status}}_{g})} x^{\text{switch-on}}_{gi} = 0 \; \text{ if } \; M^{\text{init-status}}_{g} < 0
```

- If the unit switches on, it must choose exactly one startup category:

```math
x^{\text{switch-on}}_{gt} = \sum_{k=1}^{K^{start}_g} x^{\text{start}}_{gtk}
```

- If unit has not switched off in the last "delay" time periods, then startup category is forbidden.
  The last startup category is always allowed.
  In the equation below, $L^{\text{start}}_{gtk}=1$ if category should be allowed based on initial status.

```math
x^{\text{start}}_{gtk} \leq L^{\text{start}}_{gtk} + \sum_{i=min\left(1,t - M^{\text{delay}}_{g,k+1} + 1\right)}^{t - M^{\text{delay}}_{kg}} x^{\text{switch-off}}_{gi}
```

- Link the binary variables together:

```math
\begin{align*}
& x^{\text{is-on}}_{gt} - x^{\text{is-on}}_{g,t-1} = x^{\text{switch-on}}_{gt} - x^{\text{switch-off}}_{gt} & \forall t > 1 \\
\end{align*}
```

- If the unit is off, it cannot produce power or provide reserves. If it is on, it must to so within the specified production limits:

```math
y^{\text{prod-above}}_{gts} + \sum_{r \in R_g} y^{\text{res}}_{grts} \leq
(M^{\text{pmax}}_{gt} - M^{\text{pmin}}_{gt}) x^{\text{is-on}}_{gt}
```

- Break down the "production above" variable into smaller "segment production" variables, to simplify the objective function:

```math
y^{\text{prod-above}}_{gts} = \sum_{k=1}^{K^{cost}_g} y^{\text{seg-prod}}_{gtks}
```

- Unit cannot increase its production too quickly:

```math
y^{\text{prod-above}}_{gts} + \sum_{r \in R_g} y^{\text{res}}_{grts} \leq
y^{\text{prod-above}}_{g,t-1,s} + M^{\text{ramp-up}}_{g}
```

- Same as above, for initial time:

```math
y^{\text{prod-above}}_{g,1,s} + \sum_{r \in R_g} y^{\text{res}}_{gr,1,s} \leq
\left(M^{\text{init-power}}_{g} - M^{\text{pmin}}_{gt}\right) + M^{\text{ramp-up}}_{g}
```

- Unit cannot decrease its production too quickly:

```math
y^{\text{prod-above}}_{gts} \geq
y^{\text{prod-above}}_{g,t-1,s} - M^{\text{ramp-down}}_{g}
```

- Same as above, for initial time:

```math
y^{\text{prod-above}}_{g,1,s} \geq
\left(M^{\text{init-power}}_{g} - M^{\text{pmin}}_{gt}\right) - M^{\text{ramp-down}}_{g}
```

## Loads

## Buses and Transmission Lines

## Energy storage

## Profiled generators

## Contingencies

## Reserves

## Price-sensitive loads

## Interfaces
