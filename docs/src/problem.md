# Problem Definition

The **Security-Constrained Unit Commitment Problem** (SCUC) is a two-stage stochastic mixed-integer linear optimization problem that aims to find the minimum-cost schedule for electricity generation while satisfying various physical, operational and economic constraints. In its most basic form, the problem is composed by:

- A set of generators, which produce power, at a given cost;
- A set of loads, which consume power;
- A transmission network, which delivers power from generators to the loads.

In addition to the basic components above, modern versions of SCUC also include a wide variety of additional components, such as _energy storage devices_, _reserves_ and _network interfaces_, to name a few. On this page, we present a complete definition of the problem as it is formulated in UC.jl. Please note that various souces in the literature may have different definitions and assumptions.

!!! warning

    The problem definition presented below is mathematically equivalent to the one solved by UC.jl, but the actual constraints enforced in the JuMP optimization model may be different, for performance reasons. For example, in this page we show only simplified ramping constraints, whereas the default UC.jl formulation uses a complex set of inequalities which better describes the convex hull, leading to better performance. For the actual constraints enforced in the model, we refer to the source code and references.

## 1. General modeling assumptions

- **Time discretization:** SCUC is a multi-period problem, with decisions typically covering a 24-hour or 36-hour time window. UC.jl assumes that this time window is discretized into time steps of fixed length. The number of time steps, as well as the duration of each time step, are configurable. In the equations below, the set of time steps is denoted by $T=\{1,2,\ldots,|T|\}$.

- **Decision under uncertainty:** SCUC is a two-stage stochastic problem. In the first stage, we must decide the _commitment status_ of all thermal generators. In the second stage, we determine the remaining decision variables, such power output of all generators, the operation of energy storage devices and load shedding. Stochasticity is modeled through a discrete number of scenarios $s \in S$, each with given probability $p(S)$. The goal is to minimize the minimum expected cost. The deterministic version of SCUC can be modeled by assuming a single scenario with probability 1.

## 2. Thermal generators

A _thermal generator_ is a power generation unit that converts thermal energy, typically from the combustion of coal, natural gas or oil, into electrical energy. Scheduling thermal generators is particularly complex due to their operational characteristics, including minimum up and down times, ramping rates, and start-up and shutdown limits.

### Important concepts

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

## 3. Profiled generators

A _profiled generator_ is a simplified generator model that can be used to represent renewable energy resources, including wind, solar and hydro. Unlike thermal generators, which can be either on or off, profiled generators do not have status variables; the only optimization decision is on their power output level, which must remain between minimum and maximum time-varying amounts. Production cost curves for profiled generators are linear, making them again much simpler than thermal units.

### Constants

| Symbol                  | Unit  | Description                                        |
| :---------------------- | :---- | :------------------------------------------------- |
| $M^{\text{pmax}}_{sgt}$ | MW    | Maximum power output at time $t$ and scenario $s$. |
| $M^{\text{pmin}}_{sgt}$ | MW    | Minimum power output at time $t$ and scenario $s$. |
| $Z^{\text{pvar}}_{sgt}$ | \$/MW | Generation cost at time $t$ and scenario $s$.      |

### Decision variables

| Symbol                | Unit | Description                                                  | Stage |
| :-------------------- | :--- | :----------------------------------------------------------- | :---- |
| $y^\text{prod}_{sgt}$ | MW   | Amount of power produced by $g$ in time $t$ and scenario $s$ | 2     |

### Objective function terms

- Production cost:

```math
\sum_{s \in S} p(s) \left[
  \sum_{t \in T} y^\text{prod}_{sgt} Z^{\text{pvar}}_{sgt}
\right]
```

### Constraints

- Bounds:

```math
M^{\text{pmin}}_{sgt} \leq y^\text{prod}_{sgt} \leq M^{\text{pmax}}_{sgt}
```

## 4. Conventional loads

Loads represent the demand for electrical power by consumers and devices connected to the system. This section describes conventional (or inelastic) loads, which are not sensitive to changes in electricity prices, and must always be served. Each bus in the transmission network has exactly one load; multiple loads in the same bus can be modelled by aggregating them. If there is not enough production or transmission capacity to serve all loads, some load can be shed at a penalty.

### Constants

| Symbol                  | Unit  | Description                                               |
| :---------------------- | :---- | :-------------------------------------------------------- |
| $M^\text{load}_{sbt}$   | MW    | Conventional load on bus $b$ at time $s$ and scenario $s$ |
| $Z^\text{curtail}_{st}$ | \$/MW | Load curtailment penalty at time $t$ in scenario $s$      |

### Decision variables

| Symbol                   | Unit | Description                                                      | Stage |
| :----------------------- | :--- | :--------------------------------------------------------------- | :---- |
| $y^\text{curtail}_{sbt}$ | MW   | Amount of load curtailed at bus $b$ in time $t$ and scenario $s$ | 2     |

### Objective function terms

- Load curtailment penalty:

```math
\sum_{s \in S} p(s) \left[
  \sum_{b \in B} \sum_{t \in T} y^\text{curtail}_{sbt} Z^\text{curtail}_{ts}
\right]
```

### Constraints

- Bounds:

```math
0 \leq y^\text{curtail}_{sbt} \leq M^\text{load}_{bts}
```

## 5. Price-sensitive loads

Price-sensitive loads refer to components in the system which may increase or reduce their power consumption according to energy prices. Unlike convential loads, described above, price-sensitive loads are only served if it is economical to do so. More specifically, there are no constraints forcing these loads to be served; instead, there is a term in the objective function rewarding each MW served. There may be multiple price-sensitive loads per bus.

### Sets and constants

| Symbol                       | Unit  | Description                                                     |
| :--------------------------- | :---- | :-------------------------------------------------------------- |
| $M^\text{psl-demand}_{spt}$  | MW    | Demand of price-sensitive load $p$ at time $t$ and scenario $s$ |
| $Z^\text{psl-revenue}_{spt}$ | \$/MW | Revenue from serving load $p$ at $t$ in scenario $s$            |
| $\text{PSL}$                 |       | Set of price-sensitive loads                                    |

### Decision variables

| Symbol               | Unit | Description                                       | Stage |
| :------------------- | :--- | :------------------------------------------------ | :---- |
| $y^\text{psl}_{spt}$ | MW   | Amount served to $p$ in time $t$ and scenario $s$ | 2     |

### Objective function terms

- Revenue from serving price-sensitive loads:

```math
  - \sum_{s \in S} p(s) \left[
    \sum_{p \in \text{PSL}} \sum_{t \in T} y^\text{psl}_{spt} Z^\text{psl-revenue}_{spt}
  \right]
```

### Constraints

- Bounds:

```math
0 \leq y^\text{psl}_{spt} \leq M^\text{psl-demand}_{spt}
```

## 6. Buses and transmission lines

So far, we have described generators, which produce power, and loads, which consume power. A third important element is the transmission network, which delivers the power produced by the generators to the loads. Mathematically, the network is represented as a graph $(B,L)$ where $B$ is the set of **buses** and $L$ is the set of **transmission lines**. Each generator and each bus in the network is located at a bus. The **net injection** at the bus is the sum of all power injected minus withdrawn at the bus. To balance production and consumption, we must enforce that the sum of all net injections over the network equal to zero.

Besides the net balance equations, we must also enforce flow limits on the transmission lines. Unlike flows in other optimization problems, power flows are directly determined by net injections and transmission line parameters, and must follow physical laws. UC.jl uses the DC linearization of AC power flow equations, which are derived the assumptions that (i) line losses are negligible; (ii) voltage magnitudes are constant; and (iii) phase angle differences are small. Under these assumptions, the flow $f_l$ in transmission line $l$ is given by $\sum_{b \in B} \delta_{bl} n_b$, where $\delta_{bl}$ is a constant known as _injection shift factor_, computed from the line parameters, and $n_b$ is the net injection at bus $b$.

### Sets and constants

| Symbol | Unit | Description               |
| :----- | :--- | :------------------------ |
| $B$    |      | Set of buses              |
| $L$    |      | Set of transmission lines |

| $M^{}\_{}

| $M^\text{psl-demand}_{spt}$ | MW | Demand of price-sensitive load $p$ at time $t$ and scenario $s$ |
| $Z^\text{psl-revenue}_{spt}$ | \$/MW | Revenue from serving load $p$ at $t$ in scenario $s$ |
| $\text{PSL}$ | | Set of price-sensitive loads |

### Decision variables

| Symbol               | Unit | Description                                       | Stage |
| :------------------- | :--- | :------------------------------------------------ | :---- |
| $y^\text{psl}_{spt}$ | MW   | Amount served to $p$ in time $t$ and scenario $s$ | 2     |

### Objective function terms

- Revenue from serving price-sensitive loads:

```math
  - \sum_{s \in S} p(s) \left[
    \sum_{p \in \text{PSL}} \sum_{t \in T} y^\text{psl}_{spt} Z^\text{psl-revenue}_{spt}
  \right]
```

### Constraints

- Bounds:

```math
0 \leq y^\text{psl}_{spt} \leq M^\text{psl-demand}_{spt}
```

## 7. Transmission interfaces

## 7. Energy storage devices

## 8. Contingencies

## 9. Reserves
