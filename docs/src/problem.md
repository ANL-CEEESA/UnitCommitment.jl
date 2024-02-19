# Problem Definition

The **Security-Constrained Unit Commitment Problem** (SCUC) is a two-stage stochastic mixed-integer linear optimization problem that aims to find the minimum-cost schedule for electricity generation while satisfying various physical, operational and economic constraints. In its most basic form, the problem is composed by:

- A set of thermal generators, which produce power, at a given cost;
- A set of loads, which consume power;
- A transmission network, which delivers power from generators to the loads.

In addition to the basic components above, modern versions of SCUC also include a wide variety of additional components, such as _energy storage devices_, _reserves_, _price-sensitive loads_ and _network interfaces_, to name a few. On this page, we present a complete definition of the problem as it is formulated in UC.jl. Please note that various souces in the literature may have different definitions.

## 1. Thermal Generators

A _thermal generator_ is a power generation unit that converts thermal energy, typically from the combustion of coal, natural gas or oil, into electrical energy. Scheduling thermal generators is particularly complex due to their operational characteristics, including minimum up and down times, ramping rates, and start-up and shutdown limits. Production costs for thermal generators follow a (linearized) convex production cost curve. Additionally, startup costs depend on how long has the unit been offline (e.g. cold, hot).

### Sets and constants

| Symbol                       | Unit   | Description                                                                                                |
| :--------------------------- | :----- | :--------------------------------------------------------------------------------------------------------- |
| $M^{\text{min-up}}_{g}$      |        | Minimum amount of time $g$ must stay on after switching on                                                 |
| $M^{\text{init-status}}_{g}$ |        | Initial status of unit $g$                                                                                 |
| $M^{\text{init-power}}_{g}$  |        | Initial status of unit $g$                                                                                 |
| $M^{\text{must-run}}_{gt}$   | Binary | One if unit $g$ must be on at time $t$                                                                     |
| $M^{\text{delay}}_{gk}$      |        | Delay for startup category $k$                                                                             |
| $M^{\text{pmax}}_{gt}$       | MW     | Maximum power output of $g$ at time $t$                                                                    |
| $M^{\text{pmin}}_{gt}$       | MW     | Minimum power output of $g$ at time $t$                                                                    |
| $M^{\text{ramp-up}}_{g}$     | MW     | Ramp up limit of unit $g$                                                                                  |
| $M^{\text{ramp-down}}_{g}$   | MW     | Ramp down limit of unit $g$                                                                                |
| $Z^{\text{pmin}}_{gt}$       | \$     | Cost to keep $g$ operational at time $t$ generating at minimum power                                       |
| $Z^{\text{start}}_{gk}$      | \$     | Cost to start unit $g$ at startup category $k$                                                             |
| $Z^{\text{pvar}}_{gtks}$     | \$/MW  | Cost for unit $g$ to produce 1 MW of power under piecewise-linear segment $k$ at time $t$ and scenario $s$ |
| $K^{start}_g$                |        | Number of startup categories for generator $g$ (e.g. cold, warm, hot)                                      |
| $K^{cost}_g$                 |        | Number of piecewise linear segments in the production cost curve                                           |
| $R_g$                        |        | Set of spinning reserves that may be served by $g$                                                         |
| $S$                          |        | Set of scenarios                                                                                           |

### Decision variables

| Symbol                        | Description                                                                                  | Unit   | Stage |
| :---------------------------- | :------------------------------------------------------------------------------------------- | :----- | :---- |
| $x^{\text{is-on}}_{gt}$       | One if generator $g$ is on at time $t$                                                       | Binary | 1     |
| $x^{\text{switch-on}}_{gt}$   | One if generator $g$ switches on at time $t$                                                 | Binary | 1     |
| $x^{\text{switch-off}}_{gt}$  | One if generator $g$ switches off at time $t$                                                | Binary | 1     |
| $x^{\text{start}}_{gtk}$      | One if generator $g$ starts up at time $t$ under startup category $k$                        | Binary | 1     |
| $y^{\text{prod-above}}_{gts}$ | Amount of power produced by $g$ at time $t$ in scenario $s$ above the minimum power          | MW     | 2     |
| $y^{\text{seg-prod}}_{gtks}$  | Amount of power produced by $g$ at time $t$ in piecewise-linear segment $k$ and scenario $s$ | MW     | 2     |
| $y^{\text{res}}_{grts}$       | Amount of spinning reserve $r$ supplied by $g$ at time $t$ in scenario $s$                   | MW     | 2     |

### Objective function terms

- Production costs:

```math
\sum_{g \in G} \sum_{t \in T} x^{\text{is-on}}_{gt} Z^{\text{pmin}}_{gt}
+ \sum_{s \in S} p(s) \left[
    \sum_{g \in G} \sum_{t \in T} \sum_{k=1}^{K^{cost}_g}
    y^{\text{seg-prod}}_{gtks} Z^{\text{pvar}}_{gtks}
\right]
```

- Start-up cost:

```math
\sum_{g \in G} \sum_{t \in T} \sum_{k=1}^{K^{start}_g} x^{\text{start}}_{gtk} Z^{\text{start}}_{gk}
```

### Constraints

- Must run:

```math
x^{\text{is-on}}_{gt} \geq M^{\text{must-run}}_{gt}
```

- Minimum up-time:

```math
\sum_{i=max(1,t-M^{\text{min-up}}_{g}+1)}^t x^{\text{switch-on}}_{gi} \leq x^{\text{is-on}}_{gt}
```

- Minimum up-time (initial periods):

```math
\sum_{i=1}^{min(T,M^{\text{min-up}}_{g}-M^{\text{init-status}}_{g})} x^{\text{switch-off}}_{gi} = 0 \; \text{ if } \; M^{\text{init-status}}_{g} > 0
```

- Minimum down-time:

```math
\sum_{i=max(1,t-M^{\text{min-down}}_{g}+1)}^t x^{\text{switch-off}}_{gi} \leq 1 - x^{\text{is-on}}_{gt}
```

- Minimum down-time (initial periods):

```math
\sum_{i=1}^{min(T,M^{\text{min-down}}_{g}+M^{\text{init-status}}_{g})} x^{\text{switch-on}}_{gi} = 0 \; \text{ if } \; M^{\text{init-status}}_{g} < 0
```

- Must choose one startup category:

```math
x^{\text{switch-on}}_{gt} = \sum_{k=1}^{K^{start}_g} x^{\text{start}}_{gtk}
```

- If unit has not switched off in the last "delay" time periods, then startup category is forbidden.
  The last startup category is always allowed.
  In the equation below, $L^{\text{start}}_{gtk}=1$ if category should be allowed based on initial status.

```math
x^{\text{start}}_{gtk} \leq L^{\text{start}}_{gtk} + \sum_{i=min\left(1,t - M^{\text{delay}}_{g,k+1} + 1\right)}^{t - M^{\text{delay}}_{kg}} x^{\text{switch-off}}_{gi}
```

- Link binary variables. In the equation below, $L^{\text{is-initially-on}}_{g} = 1$ if $M^{\text{init-status}}_{g}$ > 0.

```math
\begin{align*}
& x^{\text{is-on}}_{gt} - x^{\text{is-on}}_{g,t-1} = x^{\text{switch-on}}_{gt} - x^{\text{switch-off}}_{gt} & \forall t > 1 \\
& x^{\text{is-on}}_{g,1} - L^{\text{is-initially-on}}_{g} = x^{\text{switch-on}}_{g,1} - x^{\text{switch-off}}_{g,1}
\end{align*}
```

- Production limits:

```math
y^{\text{prod-above}}_{gts} + \sum_{r \in R_g} y^{\text{res}}_{grts} \leq
(M^{\text{pmax}}_{gt} - M^{\text{pmin}}_{gt}) x^{\text{is-on}}_{gt}
```

- Definition of "production above":

```math
y^{\text{prod-above}}_{gts} = \sum_{k=1}^{K^{cost}_g} y^{\text{seg-prod}}_{gtks}
```

- Ramp up limit:

```math
y^{\text{prod-above}}_{gts} + \sum_{r \in R_g} y^{\text{res}}_{grts} \leq
y^{\text{prod-above}}_{g,t-1,s} + M^{\text{ramp-up}}_{g}
```

- Ramp up limit (initial time):

```math
y^{\text{prod-above}}_{g,1,s} + \sum_{r \in R_g} y^{\text{res}}_{gr,1,s} \leq
\left(M^{\text{init-power}}_{g} - M^{\text{pmin}}_{gt}\right) + M^{\text{ramp-up}}_{g}
```

- Ramp down limit:

```math
y^{\text{prod-above}}_{gts} \geq
y^{\text{prod-above}}_{g,t-1,s} - M^{\text{ramp-down}}_{g}
```

- Ramp down limit (initial time):

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
