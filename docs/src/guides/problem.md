# Problem definition

The **Security-Constrained Unit Commitment Problem** (SCUC) is formulated in
UC.jl as a two-stage stochastic mixed-integer linear optimization problem that
aims to find the minimum-cost schedule for electricity generation while
satisfying various physical, operational and economic constraints. In its most
basic form, the problem is composed by:

- A set of generators, which produce power, at a given cost;
- A set of loads, which consume power;
- A transmission network, which delivers power from generators to the loads.

In addition to the basic components above, SCUC also include a wide variety of
additional components, such as _energy storage devices_, _reserves_ and _network
interfaces_, to name a few. On this page, we present a complete definition of
the problem, as modeled in UC.jl. Please note that different sources in the
literature may have significantly different definitions and assumptions.

!!! note

    UC.jl treats deterministic SCUC instances as a special case of the stochastic problem in which there is only one scenario, named `"s1"` by default. To access second-stage decisions, therefore, you must provide this scenario name as the value for `s`. For example, `model.inner[:prod_above]["s1", g, t]`.

!!! warning

    The problem definition presented in this page is mathematically equivalent to the one solved by UC.jl. However, some constraints (ramping, piecewise-linear costs and start-up costs) have been simplified in this page for clarity. The set of constraints actually enforced by UC.jl better describes the convex hull of the problem and leads to better computational performance, but it is much more complex to describe. For further details, we refer to the package's source code and associated references.

## 1. General modeling assumptions

- **Time discretization:** SCUC is a multi-period problem, with decisions
  typically covering a 24-hour or 36-hour time window. UC.jl assumes that this
  time window is discretized into time steps of fixed length. The number of time
  steps, as well as the duration of each time step, are configurable. In the
  equations below, the set of time steps is denoted by $T=\{1,2,\ldots,|T|\}$.

- **Decision under uncertainty:** SCUC is a two-stage stochastic problem. In the
  first stage, we must decide the _commitment status_ of all thermal generators.
  In the second stage, we determine the remaining decision variables, such power
  output of all generators, the operation of energy storage devices and load
  shedding. Stochasticity is modeled through a discrete number of scenarios
  $s \in S$, each with given probability $p(S)$. The goal is to minimize the
  minimum expected cost.

## 2. Thermal generators

A _thermal generator_ is a power generation unit that converts thermal energy,
typically from the combustion of coal, natural gas or oil, into electrical
energy. Scheduling thermal generators is particularly complex due to their
operational characteristics, including minimum up and down times, ramping rates,
and start-up and shutdown limits.

### Important concepts

- **Commitment, power output and startup/shutdown costs:** Thermal generators
  can either be online (on) or offline (off). When a thermal generator is on, it
  can produce between a minimum and a maximum amount of power; when it is off,
  it cannot produce any power. Switching a generator on incurs a startup cost,
  which depends on how long the unit has been offline. More precisely, each
  thermal generator $g$ has a number $K^{start}_g$ of startup categories (e.g.,
  cold, warm and hot). Each category $k$ has a corresponding startup cost
  $Z^{\text{start}}_{gk}$, and is available only if the unit has spent at most
  $M^{\text{delay}}_{gk}$ time steps offline. Switching a generator off may also
  incur a shutdown cost $Z^{\text{shut}}_{g}$.

- **Piecewise-linear production cost curve:** Besides startup costs, thermal
  generators also incur production costs based on their power output. The
  relationship between production cost and power output is not a linear, but a
  convex curve, which is simplified using a piecewise-linear approximation. For
  this purpose, each thermal generator $g$ has a number $K^{\text{cost}}_g$ of
  piecewise-linear segments and its power output $y^{\text{prod-above}}_{gts}$
  are broken down into
  $\sum_{k=1}^{K^{\text{cost}}_g} y^{\text{seg-prod}}_{gtks}$, so that
  production costs can be more easily calculated.

- **Ramping, minimum up/down:** Due to physical and operational limits, such as
  thermal inertia and mechanical stress, thermal generators cannot vary their
  power output too dramatically from one time period to the next. Similarly,
  thermal generators cannot switch on and off too frequently; after switching on
  or off, units must remain at that state for a minimum specified number of time
  steps.

- **Startup and shutdown limit:** A thermal generator cannot shut off if its
  output power level in the immediately preceding time step is very high (above
  a specified value); the unit must first ramp down, over potentially multiple
  time steps, and only then shut off. Similarly, the unit cannot produce a very
  large amount of power (above a specified limit) immediately after starting up;
  it must ramp up over potentially multiple time steps.

- **Initial status:** The optimization process finds optimal commitment status
  and power output level for all thermal generators starting at time period 1.
  Many constraints, however, require knowledge of previous time periods (0, -1,
  -2, ...) which are not part of the optimization model. For this reason, part
  of the input data is the initial power output $M^{\text{init-power}}_{g}$ of
  unit $g$ (that is, the output at time 0) and the initial status
  $M^{\text{init-status}}_{g}$ of unit g (how many time steps has it been
  online/offline at time time 0). If $M^{\text{init-status}}_{g}$ is positive,
  its magnitude indicates how many time periods has the unit been online; and if
  negative, how has it been offline.

- **Must-run:** Due to various factors, including reliability considerations,
  some units must remain operational regardless of whether it is economical for
  them to do so. Must-run constraints are used to enforce such requirements.

- **Investment decisions:** Thermal generators may have a positive investment
  cost, which indicates that this unit is only available if an investment is
  made. An investment decision is represented by a binary variable indicating
  whether the generator has been built at a given time period. Once invested,
  the unit remains permanently available (the investment decision is
  irreversible). A generator can only be committed (turned on) after it has been
  invested in. Investment costs are incurred at the time of the investment and
  can be scaled using an investment cost weight to balance short-term
  operational costs against long-term capital expenditures.

### Sets and constants

| Symbol                           | Unit   | Description                                                                                |
| :------------------------------- | :----- | :----------------------------------------------------------------------------------------- |
| $K^{cost}_g$                     |        | Number of piecewise linear segments in the production cost curve.                          |
| $K^{start}_g$                    |        | Number of startup categories (e.g. cold, warm, hot).                                       |
| $M^{\text{delay}}_{gk}$          |        | Delay for startup category $k$.                                                            |
| $M^{\text{init-power}}_{g}$      | MW     | Initial power output of unit $g$.                                                          |
| $M^{\text{init-status}}_{g}$     |        | Initial status of unit $g$.                                                                |
| $M^{\text{min-up}}_{g}$          |        | Minimum amount of time $g$ must stay on after switching on.                                |
| $M^{\text{must-run}}_{gt}$       | Binary | One if unit $g$ must be on at time $t$.                                                    |
| $M^{\text{pmax}}_{gt}$           | MW     | Maximum power output at time $t$.                                                          |
| $M^{\text{pmin}}_{gt}$           | MW     | Minimum power output at time $t$.                                                          |
| $M^{\text{ramp-down}}_{g}$       | MW     | Ramp down limit.                                                                           |
| $M^{\text{ramp-up}}_{g}$         | MW     | Ramp up limit.                                                                             |
| $M^{\text{ns-cap}}_{g}$          | MW     | Non-spinning reserve capacity of unit $g$.                                                 |
| $M^{\text{reserve-amount}}_{rt}$ | MW     | Required amount of reserve $r$ at time $t$.                                                |
| $M^{\text{seg-pmax}}_{gtks}$     | MW     | Maximum power output for piecewise-linear segment $k$ at time $t$ and scenario $s$.        |
| $M^{\text{shutdown-limit}}_{g}$  | MW     | Maximum power unit $g$ produces immediately before shutting down                           |
| $M^{\text{startup-limit}}_{g}$   | MW     | Maximum power unit $g$ produces immediately after starting up                              |
| $D(r)$                           |        | Set of all descendant reserves of $r$ in the cascading hierarchy.                          |
| $R_g$                            |        | Set of reserves that may be served by $g$.                                                 |
| $R$                              |        | Set of all reserves (spinning and non-spinning).                                           |
| $R^+$                            |        | Set of reserves that allow shortfall.                                                      |
| $Z^{\text{pmin}}_{gt}$           | \$     | Cost to keep $g$ operational at time $t$ generating at minimum power.                      |
| $Z^{\text{res-short}}_{r}$       | \$/MW  | Penalty for reserve shortfall for reserve $r$.                                             |
| $Z^{\text{pvar}}_{gtks}$         | \$/MW  | Cost for unit $g$ to produce 1 MW of power under piecewise-linear segment $k$ at time $t$. |
| $Z^{\text{start}}_{gk}$          | \$     | Cost to start unit $g$ at startup category $k$.                                            |
| $Z^{\text{shut}}_{g}$            | \$     | Cost to shut down unit $g$.                                                                |
| $Z^{\text{invest}}_{gt}$         | \$     | Cost to invest unit $g$ at time $t$.                                                       |
| $W^{\text{invest}}$              |        | Investment cost weight (multiplier applied to all investment costs).                       |
| $G^\text{therm}$                 |        | Set of thermal generators.                                                                 |

### Decision variables

| Symbol                        | JuMP name                  | Description                                                                                                              | Unit   | Stage |
| :---------------------------- | :------------------------- | :----------------------------------------------------------------------------------------------------------------------- | :----- | :---- |
| $x^{\text{is-on}}_{gt}$       | `is_on[g,t]`               | One if generator $g$ is on at time $t$.                                                                                  | Binary | 1     |
| $x^{\text{switch-on}}_{gt}$   | `switch_on[g,t]`           | One if generator $g$ switches on at time $t$.                                                                            | Binary | 1     |
| $x^{\text{switch-off}}_{gt}$  | `switch_off[g,t]`          | One if generator $g$ switches off at time $t$.                                                                           | Binary | 1     |
| $x^{\text{start}}_{gtk}$      | `startup[g,t,s]`           | One if generator $g$ starts up at time $t$ under startup category $k$.                                                   | Binary | 1     |
| $x^{\text{invest}}_{gt}$      | `invest[g,t]`              | One if generator $g$ is invested at or before $t$.                                                                       | Binary | 1     |
| $y^{\text{prod-above}}_{gts}$ | `prod_above[s,g,t]`        | Amount of power produced by $g$ at time $t$ in scenario $s$ above the minimum power.                                     | MW     | 2     |
| $y^{\text{seg-prod}}_{gtks}$  | `segprod[s,g,t,k]`         | Amount of power produced by $g$ at time $t$ in piecewise-linear segment $k$ and scenario $s$.                            | MW     | 2     |
| $y^{\text{res}}_{grts}$       | `reserve[s,r,g,t]`         | Amount of reserve $r$ supplied by $g$ at time $t$ in scenario $s$.                                                       | MW     | 2     |
| $y^{\text{res-short}}_{srt}$  | `reserve_shortfall[s,r,t]` | Amount of reserve shortfall for reserve $r$ at time $t$ in scenario $s$. Only defined for reserves that allow shortfall. | MW     | 2     |

### Objective function terms

- Production costs:

```math
\sum_{g \in G^\text{therm}} \sum_{t \in T} x^{\text{is-on}}_{gt} Z^{\text{pmin}}_{gt}
+ \sum_{s \in S} p(s) \left[
    \sum_{g \in G^\text{therm}} \sum_{t \in T} \sum_{k=1}^{K^{cost}_g}
    y^{\text{seg-prod}}_{gtks} Z^{\text{pvar}}_{gtks}
\right]
```

- Start-up costs:

```math
\sum_{g \in G} \sum_{t \in T} \sum_{k=1}^{K^{start}_g} x^{\text{start}}_{gtk} Z^{\text{start}}_{gk}
```

- Shutdown costs:

```math
\sum_{g \in G^\text{therm}} \sum_{t \in T} x^{\text{switch-off}}_{gt} Z^{\text{shut}}_{g}
```

- Spinning reserve shortfall penalty:

```math
\sum_{s \in S} p(s) \left[
    \sum_{r \in R^+} \sum_{t \in T} y^{\text{res-short}}_{srt} Z^{\text{res-short}}_{r}
\right]
```

- Investment costs:

```math
W^{\text{invest}} \sum_{g \in G} \sum_{t \in T} Z^{\text{invest}}_{gt} \left(x^{\text{invest}}_{gt} - x^{\text{invest}}_{g,t-1} \right)
```

### Constraints

- Some units must remain on, even if it is not economical for them to do so
  (`eq_must_run[g,t]`):

```math
x^{\text{is-on}}_{gt} \geq 1 \quad \forall (g,t): M^{\text{must-run}}_{gt} = 1
```

- After switching on, unit must remain on for some amount of time
  (`eq_min_uptime[g,t]`):

```math
\sum_{i=max(1,t-M^{\text{min-up}}_{g}+1)}^t x^{\text{switch-on}}_{gi} \leq x^{\text{is-on}}_{gt}
```

- Same as above, but covering the initial time steps (`eq_min_uptime[g,0]`):

```math
\sum_{i=1}^{min(T,M^{\text{min-up}}_{g}-M^{\text{init-status}}_{g})} x^{\text{switch-off}}_{gi} = 0 \; \text{ if } \; M^{\text{init-status}}_{g} > 0
```

- After switching off, unit must remain offline for some amount of time
  (`eq_min_downtime[g,t]`):

```math
\sum_{i=max(1,t-M^{\text{min-down}}_{g}+1)}^t x^{\text{switch-off}}_{gi} \leq 1 - x^{\text{is-on}}_{gt}
```

- Same as above, but covering the initial time steps (`eq_min_downtime[g,0]`):

```math
\sum_{i=1}^{min(T,M^{\text{min-down}}_{g}+M^{\text{init-status}}_{g})} x^{\text{switch-on}}_{gi} = 0 \; \text{ if } \; M^{\text{init-status}}_{g} < 0
```

- If the unit switches on, it must choose exactly one startup category
  (`eq_startup_choose[g,t]`):

```math
x^{\text{switch-on}}_{gt} = \sum_{k=1}^{K^{start}_g} x^{\text{start}}_{gtk}
```

- If unit has not switched off in the last "delay" time periods, then startup
  category is forbidden (`eq_startup_restrict[g,t,s]`). The last startup
  category is always allowed. In the equation below, $L^{\text{start}}_{gtk}=1$
  if category should be allowed based on initial status.

```math
x^{\text{start}}_{gtk} \leq L^{\text{start}}_{gtk} + \sum_{i=\max\left(1,t - M^{\text{delay}}_{g,k+1} + 1\right)}^{t - M^{\text{delay}}_{gk}} x^{\text{switch-off}}_{gi}
```

- Link the binary variables together (`eq_binary_link[g,t]`):

```math
\begin{align*}
& x^{\text{is-on}}_{gt} - x^{\text{is-on}}_{g,t-1} = x^{\text{switch-on}}_{gt} - x^{\text{switch-off}}_{gt} & \forall t > 1 \\
\end{align*}
```

- Cannot switch on and off at the same time (`eq_switch_on_off[g,t]`):

```math
x^{\text{switch-on}}_{gt} + x^{\text{switch-off}}_{gt} \leq 1
```

- If the unit is off, it cannot produce power or provide reserves. If it is on,
  it must to so within the specified production limits (`eq_prod_limit[s,g,t]`):

```math
y^{\text{prod-above}}_{gts} + \sum_{r \in R_g} y^{\text{res}}_{grts} \leq
(M^{\text{pmax}}_{gt} - M^{\text{pmin}}_{gt}) x^{\text{is-on}}_{gt}
```

- Break down the "production above" variable into smaller "segment production"
  variables, to simplify the objective function (`eq_prod_above_def[s,g,t]`):

```math
y^{\text{prod-above}}_{gts} = \sum_{k=1}^{K^{cost}_g} y^{\text{seg-prod}}_{gtks}
```

- Impose upper limit on segment production variables (implemented as variable
  bound):

```math
0 \leq y^{\text{seg-prod}}_{gtks} \leq M^{\text{seg-pmax}}_{gtks}
```

- Unit cannot increase its production too quickly (`eq_ramp_up[s,g,t]`):

```math
y^{\text{prod-above}}_{gts} + \sum_{r \in R_g} y^{\text{res}}_{grts} \leq
y^{\text{prod-above}}_{g,t-1,s} + M^{\text{ramp-up}}_{g}
```

- Same as above, for initial time (`eq_ramp_up[s,g,1]`). Only enforced when
  $M^{\text{init-status}}_{g} > 0$ (unit was on at $t=0$):

```math
y^{\text{prod-above}}_{g,1,s} + \sum_{r \in R_g} y^{\text{res}}_{gr,1,s} \leq
\left(M^{\text{init-power}}_{g} - M^{\text{pmin}}_{g,1}\right) + M^{\text{ramp-up}}_{g}
```

- Unit cannot decrease its production too quickly (`eq_ramp_down[s,g,t]`):

```math
y^{\text{prod-above}}_{gts} \geq
y^{\text{prod-above}}_{g,t-1,s} - M^{\text{ramp-down}}_{g}
```

- Same as above, for initial time (`eq_ramp_down[s,g,1]`). Only enforced when
  $M^{\text{init-status}}_{g} > 0$ (unit was on at $t=0$):

```math
y^{\text{prod-above}}_{g,1,s} \geq
\left(M^{\text{init-power}}_{g} - M^{\text{pmin}}_{g,1}\right) - M^{\text{ramp-down}}_{g}
```

- Combined startup and shutdown limit. When $M^{\text{min-up}}_g > 1$, startup
  and shutdown cannot occur simultaneously, so both terms can be combined into a
  single constraint (`eq_slimit_a[s,g,t]`):

```math
y^{\text{prod-above}}_{gts} + \sum_{r \in R_g} y^{\text{res}}_{grts} \leq
(M^{\text{pmax}}_{gt} - M^{\text{pmin}}_{gt}) x^{\text{is-on}}_{gt} -
(M^{\text{pmax}}_{gt} - M^{\text{startup-limit}}_{g})
x^{\text{switch-on}}_{gt} -
(M^{\text{pmax}}_{gt} - M^{\text{shutdown-limit}}_{g})
x^{\text{switch-off}}_{g,t+1}
```

- When $M^{\text{min-up}}_g \leq 1$, startup and shutdown may occur at the same
  time step, so the limits must be imposed separately. Unit cannot produce
  excessive amount of power immediately after starting up
  (`eq_slimit_b[s,g,t]`):

```math
y^{\text{prod-above}}_{gts} + \sum_{r \in R_g} y^{\text{res}}_{grts} \leq
(M^{\text{pmax}}_{gt} - M^{\text{pmin}}_{gt}) x^{\text{is-on}}_{gt} -
(M^{\text{pmax}}_{gt} - M^{\text{startup-limit}}_{g})
x^{\text{switch-on}}_{gt}
```

- Unit cannot shut off if it is producing too much power (`eq_slimit_c[s,g,t]`):

```math
y^{\text{prod-above}}_{gts} + \sum_{r \in R_g} y^{\text{res}}_{grts} \leq
(M^{\text{pmax}}_{gt} - M^{\text{pmin}}_{gt}) x^{\text{is-on}}_{gt} -
(M^{\text{pmax}}_{gt} - M^{\text{shutdown-limit}}_{g})
x^{\text{switch-off}}_{g,t+1}
```

- If the unit's initial power output exceeds its shutdown limit, it cannot shut
  down in the first time period (`eq_slimit_init[s,g]`):

```math
x^{\text{switch-off}}_{g,1} \leq 0 \quad \text{if } M^{\text{init-power}}_g > M^{\text{shutdown-limit}}_g
```

- The unit can only be committed if the investment has been made
  (`eq_invest_link[g, t]`). Only enforced for units with positive investment
  cost:

```math
x^{\text{is-on}}_{gt} \leq x^{\text{invest}}_{gt}
```

- Once the unit is invested in, the investment is irreversible
  (`eq_invest_nondec[g, t]`). Only enforced for units with positive investment
  cost:

```math
x^{\text{invest}}_{g,t-1} \leq x^{\text{invest}}_{gt}
```

- The total reserve (including cascading contributions from descendant reserves)
  must meet the minimum requirement (`eq_min_reserve[s,r,t]`):

```math
\sum_{g : r \in R_g} y^{\text{res}}_{grts}
+ \sum_{d \in D(r)} \sum_{g : d \in R_g} y^{\text{res}}_{gdts}
+ y^{\text{res-short}}_{srt} \geq M^{\text{reserve-amount}}_{rt}
```

- Non-spinning reserve provision is bounded by offline capacity
  (`eq_ns_reserve_capacity[s,r,g,t]`):

```math
y^{\text{res}}_{grts} \leq M^{\text{ns-cap}}_{g} \cdot (1 - x^{\text{is-on}}_{gt})
\quad \forall r \in R_g : r \text{ is non-spinning}
```

## 3. Profiled generators

A _profiled generator_ is a simplified generator model that can be used to
represent renewable energy resources, including wind, solar and hydro. Unlike
thermal generators, which can be either on or off, profiled generators do not
have status variables; the only optimization decision is on their power output
level, which must remain between minimum and maximum time-varying amounts.
Production cost curves for profiled generators are linear, making them again
much simpler than thermal units.

A profiled generator may have a positive investment cost, which indicates that
the unit is only available if an investment is made to build it. Generators have
their output bounds set to zero when not invested. Once a profiled generator is
invested in, it remains permanently available, and its output is constrained by
the time-varying minimum and maximum power profiles. Investment costs are
incurred at the time of the investment and scaled by an investment cost weight.

### Constants

| Symbol                   | Unit  | Description                                                          |
| :----------------------- | :---- | :------------------------------------------------------------------- |
| $M^{\text{pmax}}_{sgt}$  | MW    | Maximum power output at time $t$ and scenario $s$.                   |
| $M^{\text{pmin}}_{sgt}$  | MW    | Minimum power output at time $t$ and scenario $s$.                   |
| $Z^{\text{pvar}}_{sgt}$  | \$/MW | Generation cost at time $t$ and scenario $s$.                        |
| $Z^{\text{invest}}_{gt}$ | \$    | Cost to invest unit $g$ at time $t$.                                 |
| $W^{\text{invest}}$      |       | Investment cost weight (multiplier applied to all investment costs). |

### Decision variables

| Symbol                   | JuMP name     | Unit   | Description                                                   | Stage |
| :----------------------- | :------------ | :----- | :------------------------------------------------------------ | :---- |
| $x^{\text{invest}}_{gt}$ | `invest[g,t]` | Binary | One if generator $g$ is invested at or before $t$.            | 1     |
| $y^\text{prod}_{sgt}$    | `prod[s,g,t]` | MW     | Amount of power produced by $g$ in time $t$ and scenario $s$. | 2     |

### Objective function terms

- Production cost:

```math
\sum_{s \in S} p(s) \left[
  \sum_{t \in T} y^\text{prod}_{sgt} Z^{\text{pvar}}_{sgt}
\right]
```

- Investment costs:

```math
W^{\text{invest}} \sum_{g \in G} \sum_{t \in T} Z^{\text{invest}}_{gt} \left(x^{\text{invest}}_{gt} - x^{\text{invest}}_{g,t-1} \right)
```

### Constraints

- Variable bounds:

```math
M^{\text{pmin}}_{sgt} \leq y^\text{prod}_{sgt} \leq M^{\text{pmax}}_{sgt}
```

- Unit is permanently built once invested (`eq_invest_nondec[g, t]`):

```math
x^{\text{invest}}_{g,t-1} \leq x^{\text{invest}}_{gt}
```

- Unit generation bounds are zero if not invested (`eq_invest_prod_ub[s, g, t]`
  and `eq_invest_prod_lb[s, g, t]`):

```math
M^{\text{pmin}}_{sgt} x^{\text{invest}}_{gt} \leq y^\text{prod}_{sgt} \leq M^{\text{pmax}}_{sgt} x^{\text{invest}}_{gt}
```

## 4. Price-sensitive loads

_Price-sensitive loads_ refer to components in the system which may increase or
reduce their power consumption according to energy prices. Unlike conventional
loads, described above, price-sensitive loads are only served if it is
economical to do so. More specifically, there are no constraints forcing these
loads to be served; instead, there is a term in the objective function rewarding
each MW served. Unlike conventional loads, there may be multiple price-sensitive
loads per bus.

!!! note

    Some unit commitment models allow price-sensitive loads to have a piecewise-linear convex revenue curves, similar to thermal generators. This can be achieved in UC.jl by adding multiple price-sensitive loads to the bus, one for each piecewise-linear segment.

### Sets and constants

| Symbol                       | Unit  | Description                                                      |
| :--------------------------- | :---- | :--------------------------------------------------------------- |
| $M^\text{psl-demand}_{spt}$  | MW    | Demand of price-sensitive load $p$ at time $t$ and scenario $s$. |
| $Z^\text{psl-revenue}_{spt}$ | \$/MW | Revenue from serving load $p$ at $t$ in scenario $s$.            |
| $\text{PSL}$                 |       | Set of price-sensitive loads.                                    |

### Decision variables

| Symbol               | JuMP name      | Unit | Description                                       | Stage |
| :------------------- | :------------- | :--- | :------------------------------------------------ | :---- |
| $y^\text{psl}_{spt}$ | `loads[s,p,t]` | MW   | Amount served to $p$ in time $t$ and scenario $s$ | 2     |

### Objective function terms

- Revenue from serving price-sensitive loads:

```math
  - \sum_{s \in S} p(s) \left[
    \sum_{p \in \text{PSL}} \sum_{t \in T} y^\text{psl}_{spt} Z^\text{psl-revenue}_{spt}
  \right]
```

### Constraints

- Variable bounds:

```math
0 \leq y^\text{psl}_{spt} \leq M^\text{psl-demand}_{spt}
```

## 5. Energy storage

_Energy storage_ units are able to store energy during periods of low demand,
then release energy back to the grid during periods of high demand. These
devices include _batteries_, _pumped hydroelectric storage_, _compressed air
energy storage_ and _flywheels_. They are becoming increasingly important in the
modern power grid, and can help to enhance grid reliability, efficiency and
integration of renewable energy resources.

### Concepts

- **Min/max energy level and charge rate:** Energy storage units can only store
  a limited amount of energy (in MWh). To maintain the operational safety and
  longevity of these devices, a minimum energy level may also be imposed. The
  rate (in MW) at which these units can charge and discharge is also limited,
  due to chemical, physical and operational considerations.

- **Operational costs:** Charging and discharging energy storage units may incur
  a cost/revenue. We assume that this cost/revenue is linear on the
  charge/discharge rate ($/MW).

- **Efficiency:** Charging an energy storage unit for one hour with an input of
  1 MW might not result in an increase of the energy level in the device by
  exactly 1 MWh, due to various inefficiencies in the charging process,
  including conversion losses and heat generation. For similar reasons,
  discharging a storage unit for one hour at 1 MW might reduce the energy level
  by more than 1 MWh. Furthermore, even when the unit is not charging or
  discharging, some energy level may be gradually lost over time, due to
  unwanted chemical reactions, thermal effects of mechanical losses.

- **Myopic effect:** Because the optimization process considers a fixed time
  window, there is an inherent bias towards exploiting energy storage units to
  their maximum within the window, completely ignoring their operation just
  beyond this horizon. For instance, without further constraints, the
  optimization algorithm will often ensure that all storage units are fully
  discharged at the end of the last time step, which may not be desirable. To
  mitigate this myopic effect, a minimum and maximum energy level may be imposed
  at the last time step.

- **Simultaneous charging and discharging:** Depending on charge and discharge
  costs/revenue, it may make sense mathematically to simultaneously charge and
  discharge the storage unit, thus keeping its energy level unchanged while
  potentially collecting revenue. By default, additional binary variables and
  constraints are used to prevent this incorrect model behavior. This can be
  controlled on a per-time-step basis using the $B^\text{simult}_{sut}$
  parameter.

- **Initial storage level:** Because the optimization considers a discrete time
  window, the storage level at time $t=0$ (before the first time step) must be
  provided as input data.

- **Investment decisions:** Energy storage units may have a positive investment
  cost, which indicates that the unit is only available if an investment is
  made. Once invested, the unit remains permanently available. When not
  invested, the storage level bounds are set to zero, preventing any charging or
  discharging.

### Sets and constants

| Symbol                              | Unit  | Description                                                                                           |
| :---------------------------------- | :---- | :---------------------------------------------------------------------------------------------------- |
| $\text{SU}$                         |       | Set of storage units.                                                                                 |
| $B^\text{simult}_{sut}$             |       | True if simultaneous charge and discharge is allowed for unit $u$ at time $t$ in scenario $s$.        |
| $M^\text{init-level}_{su}$          | MWh   | Initial storage level of unit $u$ in scenario $s$ (at time $t=0$).                                    |
| $M^\text{charge-max}_{sut}$         | MW    | Maximum charge rate for unit $u$ at time $t$ in scenario $s$.                                         |
| $M^\text{charge-min}_{sut}$         | MW    | Minimum charge rate for unit $u$ at time $t$ in scenario $s$.                                         |
| $M^\text{discharge-max}_{sut}$      | MW    | Maximum discharge rate for unit $u$ at time $t$ in scenario $s$.                                      |
| $M^\text{discharge-min}_{sut}$      | MW    | Minimum discharge rate for unit $u$ at time $t$ in scenario $s$.                                      |
| $M^\text{max-level}_{sut}$          | MWh   | Maximum storage level of unit $u$ at time $t$ in scenario $s$.                                        |
| $M^\text{min-level}_{sut}$          | MWh   | Minimum storage level of unit $u$ at time $t$ in scenario $s$.                                        |
| $M^\text{max-end-level}_{su}$       | MWh   | Maximum storage level of unit $u$ at the last time step in scenario $s$.                              |
| $M^\text{min-end-level}_{su}$       | MWh   | Minimum storage level of unit $u$ at the last time step in scenario $s$.                              |
| $W^{\text{invest}}$                 |       | Investment cost weight (multiplier applied to all investment costs).                                  |
| $Z^\text{charge}_{sut}$             | \$/MW | Linear charge cost/revenue for unit $u$ at time $t$ in scenario $s$.                                  |
| $Z^\text{discharge}_{sut}$          | \$/MW | Linear discharge cost/revenue for unit $u$ at time $t$ in scenario $s$.                               |
| $Z^{\text{invest}}_{ut}$            | \$    | Investment cost for unit $u$ at time $t$.                                                             |
| $\gamma^\text{charge-eff}_{sut}$    |       | Charging efficiency factor for unit $u$ at time $t$ in scenario $s$.                                  |
| $\gamma^\text{discharge-eff}_{sut}$ |       | Discharging efficiency factor for unit $u$ at time $t$ in scenario $s$.                               |
| $\gamma^\text{loss}_{sut}$          |       | Self-discharge factor for unit $u$ at time $t$ in scenario $s$.                                       |
| $\gamma^\text{time-step}$           |       | Length of a time step, in hours. Should be 1.0 for hourly time steps, 0.5 for 30-min half steps, etc. |

### Decision variables

| Symbol                          | JuMP name               | Unit   | Description                                                  | Stage |
| :------------------------------ | :---------------------- | :----- | :----------------------------------------------------------- | :---- |
| $y^\text{level}_{sut}$          | `storage_level[s,u,t]`  | MWh    | Storage level of unit $u$ at time $t$ in scenario $s$.       | 2     |
| $y^\text{charge}_{sut}$         | `charge_rate[s,u,t]`    | MW     | Charge rate of unit $u$ at time $t$ in scenario $s$.         | 2     |
| $y^\text{discharge}_{sut}$      | `discharge_rate[s,u,t]` | MW     | Discharge rate of unit $u$ at time $t$ in scenario $s$.      | 2     |
| $x^\text{is-charging}_{sut}$    | `is_charging[s,u,t]`    | Binary | True if unit $u$ is charging at time $t$ in scenario $s$.    | 2     |
| $x^\text{is-discharging}_{sut}$ | `is_discharging[s,u,t]` | Binary | True if unit $u$ is discharging at time $t$ in scenario $s$. | 2     |
| $x^\text{invest}_{ut}$          | `invest_storage[u,t]`   | Binary | True if unit $u$ is invested at or before time $t$.          | 1     |

### Objective function terms

- Charge and discharge cost/revenue:

```math
\sum_{s \in S} p(s) \left[
  \sum_{u \in \text{SU}} \sum_{t \in T} \left(
    y^\text{charge}_{sut} Z^\text{charge}_{sut} +
    y^\text{discharge}_{sut} Z^\text{discharge}_{sut}
    \right)
\right]
```

- Investment costs:

```math
W^{\text{invest}} \sum_{u \in \text{SU}} \sum_{t \in T} Z^{\text{invest}}_{ut} \left(x^{\text{invest}}_{ut} - x^{\text{invest}}_{u,t-1} \right)
```

### Constraints

- Variable bounds for storage level:

```math
M^\text{min-level}_{sut} \leq y^\text{level}_{sut} \leq M^\text{max-level}_{sut}
```

- Prevent simultaneous charge and discharge
  (`eq_simultaneous_charge_and_discharge[s,u,t]`). This constraint is only added
  when $B^\text{simult}_{sut}$ is false:

```math
x^\text{is-charging}_{sut} + x^\text{is-discharging}_{sut} \leq 1
```

- Limit charge rate (`eq_min_charge_rate[s,u,t]` and
  `eq_max_charge_rate[s,u,t]`):

```math
x^\text{is-charging}_{sut} M^\text{charge-min}_{sut} \leq y^\text{charge}_{sut} \leq x^\text{is-charging}_{sut} M^\text{charge-max}_{sut}
```

- Limit discharge rate (`eq_min_discharge_rate[s,u,t]` and
  `eq_max_discharge_rate[s,u,t]`):

```math
x^\text{is-discharging}_{sut} M^\text{discharge-min}_{sut} \leq y^\text{discharge}_{sut} \leq x^\text{is-discharging}_{sut} M^\text{discharge-max}_{sut}
```

- Calculate current storage level (`eq_storage_transition[s,u,t]`). For $t=1$,
  $y^\text{level}_{su,t-1}$ is replaced by the initial level
  $M^\text{init-level}_{su}$:

```math
y^\text{level}_{sut} =
(1 - \gamma^\text{loss}_{sut}) y^\text{level}_{su,t-1} +
\gamma^\text{time-step} \gamma^\text{charge-eff}_{sut} y^\text{charge}_{sut} -
\frac{\gamma^\text{time-step}}{\gamma^\text{discharge-eff}_{sut}} y^\text{discharge}_{sut}
```

- Enforce storage level at last time step (`eq_ending_level[s,u]`):

```math
M^\text{min-end-level}_{su} \leq y^\text{level}_{su,|T|} \leq M^\text{max-end-level}_{su}
```

- Storage is permanently built once invested (`eq_invest_storage_nondec[u,t]`):

```math
x^{\text{invest}}_{u,t-1} \leq x^{\text{invest}}_{ut}
```

- Storage level bounds depend on investment status
  (`eq_invest_storage_level_ub[s,u,t]` and `eq_invest_storage_level_lb[s,u,t]`).
  These constraints replace the variable bounds above for units with investment
  decisions:

```math
M^\text{min-level}_{sut} x^{\text{invest}}_{ut} \leq y^\text{level}_{sut} \leq M^\text{max-level}_{sut} x^{\text{invest}}_{ut}
```

## 6. Virtual transactions

_Virtual transactions_ are financial instruments used in day-ahead electricity
markets. They allow traders to buy or sell power at specific locations without
physical delivery. Three types are supported:

- **INC (Increment offer):** Offers to sell power at a bus. If cleared, injects
  virtual supply and receives the LMP.
- **DEC (Decrement bid):** Bids to buy power at a bus. If cleared, withdraws
  virtual demand and pays the LMP.
- **UTC (Up-to-congestion):** A paired injection at a source bus and withdrawal
  at a sink bus. The trader profits from the spread between the two LMPs.

### Sets and constants

| Symbol                      | Unit  | Description                                                               |
| :-------------------------- | :---- | :------------------------------------------------------------------------ |
| $\text{VT}$                 |       | Set of virtual transactions.                                              |
| $\text{VT}^{\text{inc}}$    |       | Subset of INC transactions.                                               |
| $\text{VT}^{\text{dec}}$    |       | Subset of DEC transactions.                                               |
| $\text{VT}^{\text{utc}}$    |       | Subset of UTC transactions.                                               |
| $M^{\text{vt-qmax}}_{svt}$  | MW    | Maximum quantity for virtual transaction $v$ at time $t$ in scenario $s$. |
| $Z^{\text{vt-price}}_{svt}$ | \$/MW | Offer/bid price for virtual transaction $v$ at time $t$ in scenario $s$.  |
| $\text{VT}^{\text{inj}}_b$  |       | Set of virtual transactions injecting at bus $b$.                         |
| $\text{VT}^{\text{wdr}}_b$  |       | Set of virtual transactions withdrawing from bus $b$.                     |

### Decision variables

| Symbol                | JuMP name           | Unit | Description                                                             | Stage |
| :-------------------- | :------------------ | :--- | :---------------------------------------------------------------------- | :---- |
| $y^{\text{vt}}_{svt}$ | `vt_cleared[s,v,t]` | MW   | Amount cleared for virtual transaction $v$ at time $t$ in scenario $s$. | 2     |

### Objective function terms

- INC offer cost (supply offers energy at a price):

```math
\sum_{s \in S} p(s) \left[
  \sum_{v \in \text{VT}^{\text{inc}}} \sum_{t \in T}
  y^{\text{vt}}_{svt} Z^{\text{vt-price}}_{svt}
\right]
```

- DEC bid benefit (demand is willing to pay for energy):

```math
- \sum_{s \in S} p(s) \left[
  \sum_{v \in \text{VT}^{\text{dec}}} \sum_{t \in T}
  y^{\text{vt}}_{svt} Z^{\text{vt-price}}_{svt}
\right]
```

- UTC spread bid (trader pays for congestion spread):

```math
- \sum_{s \in S} p(s) \left[
  \sum_{v \in \text{VT}^{\text{utc}}} \sum_{t \in T}
  y^{\text{vt}}_{svt} Z^{\text{vt-price}}_{svt}
\right]
```

### Constraints

- Variable bounds:

```math
0 \leq y^{\text{vt}}_{svt} \leq M^{\text{vt-qmax}}_{svt}
```

## 7. Shunt devices

Shunt devices are fixed impedance elements connected between a bus and ground,
typically used to model reactive power compensation equipment (e.g., capacitor
banks, reactors) or constant-impedance loads. Each shunt device has a
conductance and susceptance (in per-unit), and a time-varying on/off status.
Under the DC approximation (where voltage magnitudes are assumed to be 1.0
p.u.), the active power consumed by a shunt device is
$M^{\text{sh-cond}}_{sk} \cdot M^\text{base}_s$ MW, where
$M^{\text{sh-cond}}_{sk}$ is its conductance and $M^\text{base}_s$ is the system
base MVA. This power consumption appears as a loss in the power balance
constraints.

### Sets and constants

| Symbol                       | Unit | Description                                                      |
| :--------------------------- | :--- | :--------------------------------------------------------------- |
| $M^{\text{sh-cond}}_{sk}$    | p.u. | Conductance of shunt device $k$ in scenario $s$.                 |
| $M^\text{base}_{s}$          | MVA  | System base MVA in scenario $s$.                                 |
| $M^{\text{sh-status}}_{skt}$ |      | Status (on/off) of shunt device $k$ at time $t$ in scenario $s$. |
| $\text{SH}$                  |      | Set of all shunt devices.                                        |
| $\text{SH}_b$                |      | Set of shunt devices at bus $b$.                                 |

## 8. Buses

Buses are connection points in the transmission network where generators, loads,
and storage units are located. Each bus has an associated load profile
representing the power demand at that location over time. The optimization model
allows for load curtailment at each bus, which can be used to maintain
feasibility when there is insufficient generation or transmission capacity.

### Important concepts

- **Load profile:** Each bus has a time-varying load profile that represents the
  fixed power demand (or supply) at that location. Positive loads represent
  consumption, while negative loads can represent fixed generation or power
  injection (e.g., from DERs or must-run units not explicitly modeled).

- **Load curtailment:** When there is insufficient generation or transmission
  capacity, some load can be curtailed (reduced or shed) at a penalty. For
  positive loads (consumption), curtailment represents demand reduction. For
  negative loads (fixed injection), curtailment represents reduction in the
  fixed injection. Curtailment is penalized in the objective function to ensure
  it only occurs when necessary.

### Sets and constants

| Symbol                  | Unit  | Description                                                                                                |
| :---------------------- | :---- | :--------------------------------------------------------------------------------------------------------- |
| $M^\text{load}_{sbt}$   | MW    | Fixed load at bus $b$ at time $t$ in scenario $s$. Positive for consumption; negative for fixed injection. |
| $Z^\text{curtail}_{st}$ | \$/MW | Load curtailment penalty at time $t$ in scenario $s$.                                                      |

### Decision variables

| Symbol                   | JuMP name        | Unit | Description                                                                                                        | Stage |
| :----------------------- | :--------------- | :--- | :----------------------------------------------------------------------------------------------------------------- | :---- |
| $y^\text{curtail}_{sbt}$ | `curtail[s,b,t]` | MW   | Amount of load curtailed at bus $b$ at time $t$ in scenario $s$. Positive for consumption; negative for injection. | 2     |
| $y^\text{inj}_{sbt}$     | `ni[s,b,t]`      | MW   | Total net injection at bus $b$ at time $t$ in scenario $s$.                                                        | 2     |

### Objective function terms

- Load curtailment penalty:

```math
\sum_{s \in S} p(s) \left[
  \sum_{\substack{b \in B, t \in T \\ M^\text{load}_{sbt} \geq 0}} y^\text{curtail}_{sbt} Z^\text{curtail}_{st}
  - \sum_{\substack{b \in B, t \in T \\ M^\text{load}_{sbt} < 0}} y^\text{curtail}_{sbt} Z^\text{curtail}_{st}
\right]
```

### Constraints

- Curtailment variable bounds. Curtailment is limited by the magnitude of the
  load:

```math
\min(0, M^\text{load}_{sbt}) \leq y^\text{curtail}_{sbt} \leq \max(0, M^\text{load}_{sbt})
```

- Net injection definition (`eq_net_injection[s,b,t]`). The net injection
  variable equals the sum of all component contributions to the bus:

```math
\begin{align*}
y^\text{inj}_{sbt} =
  & \sum_{g \in G^{\text{therm}}_b} \left( M^{\text{pmin}}_{gt} x^{\text{is-on}}_{gt} + y^{\text{prod-above}}_{gts} \right) \\
  & + \sum_{g \in G^{\text{prof}}_b} y^\text{prod}_{sgt} \\
  & + \sum_{u \in \text{SU}_b} \left( y^\text{discharge}_{sut} - y^\text{charge}_{sut} \right) \\
  & - \sum_{p \in \text{PSL}_b} y^\text{psl}_{spt} \\
  & + \sum_{v \in \text{VT}^{\text{inj}}_b} y^{\text{vt}}_{svt} - \sum_{v \in \text{VT}^{\text{wdr}}_b} y^{\text{vt}}_{svt} \\
  & - M^\text{load}_{sbt} + y^\text{curtail}_{sbt}
\end{align*}
```

- System-wide power balance (`eq_power_balance[s,t]`). The sum of net injections
  across all buses must equal total shunt losses:

```math
\sum_{b \in B} y^\text{inj}_{sbt} = \sum_{k \in \text{SH}} M^{\text{sh-status}}_{skt} \, M^{\text{sh-cond}}_{sk} \, M^\text{base}_{s}
```

## 9. Branches

Transmission lines connect buses in the network and allow power to flow between
them. The transmission network is represented as a graph $(B,L)$ where $B$ is
the set of buses and $L$ is the set of transmission lines. Besides enforcing
power balance at each bus (as described in Section 8), we must also enforce flow
limits on the transmission lines. Unlike flows in other optimization problems,
power flows are directly determined by voltage phase angles and transmission
line parameters, and must follow physical laws. UC.jl uses the DC linearization
of AC power flow equations. Under this linearization, the flow $f_l$ in
transmission line $l$ connecting buses $b$ (source) and $b'$ (target) is given
by $B_l (\theta_b - \theta_{b'})$, where $B_l$ is the line susceptance (in
siemens), and $\theta_b$, $\theta_{b'}$ are the voltage phase angles (in
radians) at the source and target buses, respectively. One bus in the system is
designated as the reference bus, with its phase angle fixed to zero.

For lines having a positive investment cost, the line is only present in the
network if an investment is made to build it, represented by an integer variable
indicating the number of parallel circuits constructed along a corridor by a
given time period. Once built, lines/circuits remain permanently available. The
flow on a line depends on the phase angle difference between its endpoints, the
line's susceptance, and the number of invested circuits. Thermal limits are
scaled proportionally with the number of circuits. Investment costs are incurred
at the time of investment and scaled by a cost weight. Multiple circuits may be
added over time (e.g., one at time 1, another at time 2), but the total number
of circuits cannot decrease.

!!! warning

    By default, UC.jl uses `ShiftFactorsTransmissionExt` to compute power flows, which
    has better computational performance and supports N-1 line contingencies. Under
    this extension, power flow variables and constraints are generated on-the-fly
    during `UnitCommitment.optimize!`; they are **not** added by
    `UnitCommitment.build_model`. When transmission expansion is enabled, UC.jl
    uses `PhaseAngleTransmissionExt` instead, since shift factors depend on the
    network topology and would need to be recomputed for each investment decision.

### Sets and constants

| Symbol                      | Unit  | Description                                                          |
| :-------------------------- | :---- | :------------------------------------------------------------------- |
| $B$                         |       | Set of buses.                                                        |
| $B_l$                       | S     | Susceptance of line $l$.                                             |
| $L$                         |       | Set of transmission lines.                                           |
| $M$                         | MW    | Big-M constant used in linearization of flow constraints.            |
| $M^\text{angle-max}_{l}$    | rad   | Maximum phase angle difference across line $l$ (default $+\infty$).  |
| $M^\text{angle-min}_{l}$    | rad   | Minimum phase angle difference across line $l$ (default $-\infty$).  |
| $M^\text{limit}_{slt}$      | MW    | Flow limit per circuit for line $l$ at time $t$ and scenario $s$.    |
| $M^\text{max-circuits}_{l}$ |       | Maximum number of circuits that can be invested along corridor $l$.  |
| $M^\text{phase-limit}$      | rad   | Maximum absolute value of phase angles.                              |
| $W^{\text{invest}}$         |       | Investment cost weight (multiplier applied to all investment costs). |
| $Z^\text{overflow}_{slt}$   | \$/MW | Overflow penalty for line $l$ at time $t$ and scenario $s$.          |
| $Z^{\text{invest}}_{lt}$    | \$    | Cost to invest in one circuit along corridor $l$ at time $t$.        |

### Decision variables

| Symbol                    | JuMP name         | Unit    | Description                                                           | Stage |
| :------------------------ | :---------------- | :------ | :-------------------------------------------------------------------- | :---- |
| $x^{\text{invest}}_{lt}$  | `invest[l,t]`     | Integer | Number of circuits invested along corridor $l$ at or before $t$.      | 1     |
| $y^\text{flow}_{slt}$     | `flow[s,l,t]`     | MW      | Flow on line $l$ at time $t$ and scenario $s$.                        | 2     |
| $y^\text{overflow}_{slt}$ | `overflow[s,l,t]` | MW      | Amount of flow above limit for line $l$ at time $t$ and scenario $s$. | 2     |
| $\theta_{sbt}$            | `theta[s,b,t]`    | rad     | Phase angle for bus $b$ at time $t$ and scenario $s$.                 | 2     |

### Objective function terms

- Penalty for exceeding line limits:

```math
  \sum_{s \in S} p(s) \left[
    \sum_{l \in L} \sum_{t \in T} y^\text{overflow}_{slt} Z^\text{overflow}_{slt}
  \right]
```

- Investment costs:

```math
W^{\text{invest}} \sum_{l \in L} \sum_{t \in T} Z^{\text{invest}}_{lt} \left(x^{\text{invest}}_{lt} - x^{\text{invest}}_{l,t-1} \right)
```

### Constraints

- Phase angle bounds. The reference (slack) bus has its phase angle fixed to
  zero:

```math
\begin{align*}
-M^\text{phase-limit} & \leq \theta_{sbt} \leq M^\text{phase-limit} \\
\theta_{s,b_1,t} & = 0
\end{align*}
```

- Circuits are permanently built once invested (`eq_invest_nondec[l,t]`). Only
  applies to candidate lines.

```math
x^{\text{invest}}_{l,t-1} \leq x^{\text{invest}}_{lt}
```

- DC power flow equation. Here $b$ and $b'$ are the source and target buses of
  line $l$, respectively. For existing lines, the flow is directly determined by
  the phase angle difference (`eq_dc_flow[s,l,t]`):

```math
y^\text{flow}_{slt} = B_{l} (\theta_{sbt} - \theta_{sb't})
```

- For candidate lines with $M^\text{max-circuits}_l > 1$, the flow is scaled by
  the number of invested circuits (`eq_dc_flow[s,l,t]`):

```math
y^\text{flow}_{slt} = x^{\text{invest}}_{lt} B_{l} (\theta_{sbt} - \theta_{sb't})
```

- For candidate lines with $M^\text{max-circuits}_l = 1$, the DC power flow
  constraint is linearized using a big-M formulation
  (`eq_dc_flow_bigm_ub[s,l,t]` and `eq_dc_flow_bigm_lb[s,l,t]`):

```math
\begin{align*}
y^\text{flow}_{slt} & \leq B_{l} (\theta_{sbt} - \theta_{sb't}) + M (1 - x^{\text{invest}}_{lt}) \\
y^\text{flow}_{slt} & \geq B_{l} (\theta_{sbt} - \theta_{sb't}) - M (1 - x^{\text{invest}}_{lt})
\end{align*}
```

- Flow capacity limits for existing lines (`eq_flow_limit_ub[s,l,t]` and
  `eq_flow_limit_lb[s,l,t]`). These are soft constraints that allow overflow at
  a penalty:

```math
-M^\text{limit}_{slt} - y^\text{overflow}_{slt} \leq y^\text{flow}_{slt} \leq M^\text{limit}_{slt} + y^\text{overflow}_{slt}
```

- Flow capacity limits for candidate lines, scaled by the number of invested
  circuits (`eq_flow_limit_ub[s,l,t]` and `eq_flow_limit_lb[s,l,t]`). These are
  also soft constraints:

```math
-M^\text{limit}_{slt} x^{\text{invest}}_{lt} - y^\text{overflow}_{slt} \leq y^\text{flow}_{slt} \leq M^\text{limit}_{slt} x^{\text{invest}}_{lt} + y^\text{overflow}_{slt}
```

- Nodal power balance (`eq_nodal_balance[s,b,t]`). At each bus, the net
  injection minus shunt losses must equal net incoming flow. Under the DC
  approximation, shunt conductance losses are
  $M^{\text{sh-cond}}_{sk} M^\text{base}_s$ per device (assuming $V_m = 1.0$
  p.u.):

```math
y^\text{inj}_{sbt} - \sum_{k \in \text{SH}_b} M^{\text{sh-status}}_{skt} \, M^{\text{sh-cond}}_{sk} \, M^\text{base}_s
+ \sum_{\substack{l \in L \\ \text{target}(l)=b}} y^\text{flow}_{slt}
= \sum_{\substack{l \in L \\ \text{source}(l)=b}} y^\text{flow}_{slt}
```

- Phase angle difference limits (`eq_angle_diff_ub[s,l,t]` and
  `eq_angle_diff_lb[s,l,t]`). Only enforced when the corresponding bound is
  finite:

```math
\begin{align*}
\theta_{sbt} - \theta_{sb't} & \leq M^\text{angle-max}_{l} \\
\theta_{sbt} - \theta_{sb't} & \geq M^\text{angle-min}_{l}
\end{align*}
```

## 10. Interfaces

An _interface_ (or _corridor_) is a named group of transmission lines whose
aggregate weighted flow is bounded. Interfaces are commonly used by ISOs to
model key transmission bottlenecks (e.g., North–South transfer corridors). Each
line in the interface carries a signed weight coefficient: positive weights
indicate outbound flow contributions, and negative weights indicate inbound flow
contributions.

### Sets and constants

| Symbol                        | Unit  | Description                                                     |
| :---------------------------- | :---- | :-------------------------------------------------------------- |
| $\text{IF}$                   |       | Set of interfaces.                                              |
| $L_I$                         |       | Set of transmission lines belonging to interface $I$.           |
| $M^{\text{ifc-weight}}_{Il}$  |       | Weight coefficient of line $l$ in interface $I$.                |
| $M^{\text{ifc-ub}}_{It}$      | MW    | Upper limit on net flow through interface $I$ at time $t$.      |
| $M^{\text{ifc-lb}}_{It}$      | MW    | Lower limit on net flow through interface $I$ at time $t$.      |
| $Z^{\text{ifc-penalty}}_{It}$ | \$/MW | Penalty for violating flow limits of interface $I$ at time $t$. |

### Decision variables

| Symbol                          | JuMP name                   | Unit | Description                                                                   | Stage |
| :------------------------------ | :-------------------------- | :--- | :---------------------------------------------------------------------------- | :---- |
| $y^{\text{ifc-flow}}_{sIt}$     | `interface_flow[s,I,t]`     | MW   | Net weighted flow through interface $I$ at time $t$ in scenario $s$.          | 2     |
| $y^{\text{ifc-overflow}}_{sIt}$ | `interface_overflow[s,I,t]` | MW   | Amount of flow limit violation for interface $I$ at time $t$ in scenario $s$. | 2     |

### Objective function terms

- Interface flow limit penalty:

```math
\sum_{s \in S} p(s) \left[
  \sum_{I \in \text{IF}} \sum_{t \in T}
  y^{\text{ifc-overflow}}_{sIt} \, Z^{\text{ifc-penalty}}_{It}
\right]
```

### Constraints

- Interface flow definition (`eq_interface_flow_def[s,I,t]`). The net flow
  through the interface is the weighted sum of individual line flows:

```math
y^{\text{ifc-flow}}_{sIt} = \sum_{l \in L_I} M^{\text{ifc-weight}}_{Il} \cdot y^{\text{flow}}_{slt}
```

- Upper bound on interface flow (`eq_interface_flow_ub[s,I,t]`). Only enforced
  when the upper limit is finite:

```math
y^{\text{ifc-flow}}_{sIt} \leq M^{\text{ifc-ub}}_{It} + y^{\text{ifc-overflow}}_{sIt}
```

- Lower bound on interface flow (`eq_interface_flow_lb[s,I,t]`). Only enforced
  when the lower limit is finite:

```math
y^{\text{ifc-flow}}_{sIt} \geq M^{\text{ifc-lb}}_{It} - y^{\text{ifc-overflow}}_{sIt}
```
