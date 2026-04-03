# Output data format

After solving a unit commitment problem, the solution is provided as a
structured data format containing time series data for all decision variables
and computed metrics, organized by component type.

## Structure

For stochastic instances with multiple scenarios, the solution is organized as a
nested structure:

```json
{
  "scenario1": {
    "variable_name": {
      "component_name": [value_t1, value_t2, ..., value_tT]
    }
  },
  "scenario2": {
    ...
  }
}
```

For deterministic instances (single scenario), the outer scenario layer is
removed for convenience:

```json
{
  "variable_name": {
    "component_name": [value_t1, value_t2, ..., value_tT]
  }
}
```

## Buses

| Key                                 | Description                                                                                       | Unit |
| :---------------------------------- | :------------------------------------------------------------------------------------------------ | :--- |
| `Bus: Net injection (MW)`           | Net active power injection at each bus.                                                           | MW   |
| `Bus: Load curtail (MW)`            | Amount of active load curtailed at each bus due to insufficient capacity or congestion.           | MW   |
| `Bus: Reactive load curtail (MVAr)` | Amount of reactive load curtailed at each bus. Only present when AC formulation is used.          | MVAr |
| `Bus: Voltage magnitude (p.u.)`     | Voltage magnitude at each bus. Only present when AC formulation is used.                          | p.u. |
| `Bus: Voltage angle (rad)`          | Voltage angle at each bus. Only present when AC formulation is used.                              | rad  |
| `Bus: Fixed load expense ($)`       | Expense for serving fixed load at each bus (load times LMP). Only available if LMPs are computed. | $    |

## Example

```json
{
  "Bus: Net injection (MW)": {
    "b1": [125.5, 130.2, 128.7, 135.0],
    "b2": [-50.3, -48.9, -52.1, -49.5]
  },
  "Bus: Load curtail (MW)": {
    "b1": [0.0, 0.0, 0.0, 0.0],
    "b2": [0.0, 0.0, 0.0, 0.0]
  },
  "Bus: Reactive load curtail (MVAr)": {
    "b1": [0.0, 0.0, 0.0, 0.0],
    "b2": [0.0, 0.0, 0.0, 0.0]
  },
  "Bus: Voltage magnitude (p.u.)": {
    "b1": [1.0, 1.0, 1.0, 1.0],
    "b2": [0.985, 0.987, 0.983, 0.986]
  },
  "Bus: Voltage angle (rad)": {
    "b1": [0.0, 0.0, 0.0, 0.0],
    "b2": [-0.035, -0.032, -0.038, -0.033]
  },
  "Bus: Fixed load expense ($)": {
    "b1": [3138.75, 3255.0, 3217.5, 3375.0],
    "b2": [1509.0, 1467.0, 1563.0, 1485.0]
  }
}
```

## Locational Marginal Prices

| Key                       | Description                                                                                                                  | Unit  |
| :------------------------ | :--------------------------------------------------------------------------------------------------------------------------- | :---- |
| `LMP: Total ($/MWh)`      | Total locational marginal price at each bus. Only available if LMPs are computed.                                            | $/MWh |
| `LMP: Energy ($/MWh)`     | Energy component of LMP at each bus (minimum LMP across all buses at each time period). Only available if LMPs are computed. | $/MWh |
| `LMP: Congestion ($/MWh)` | Congestion component of LMP at each bus (total LMP minus energy component). Only available if LMPs are computed.             | $/MWh |

When an AC formulation is used, LMPs reflect AC marginal pricing and may differ
from DC-based LMPs due to losses and reactive power constraints.

## Example

```json
{
  "LMP: Total ($/MWh)": {
    "b1": [25.0, 25.0, 25.0, 25.0],
    "b2": [30.0, 30.0, 30.0, 30.0],
    "b3": [25.0, 28.5, 26.2, 27.8]
  },
  "LMP: Energy ($/MWh)": {
    "b1": [25.0, 25.0, 25.0, 25.0],
    "b2": [25.0, 25.0, 25.0, 25.0],
    "b3": [25.0, 25.0, 25.0, 25.0]
  },
  "LMP: Congestion ($/MWh)": {
    "b1": [0.0, 0.0, 0.0, 0.0],
    "b2": [5.0, 5.0, 5.0, 5.0],
    "b3": [0.0, 3.5, 1.2, 2.8]
  }
}
```

## Thermal Generators

| Key                              | Description                                                                                                                                                              | Unit   |
| :------------------------------- | :----------------------------------------------------------------------------------------------------------------------------------------------------------------------- | :----- |
| `Thermal: Production (MW)`       | Total power output from each thermal generator (minimum power plus segment production).                                                                                  | MW     |
| `Thermal: Utilization (%)`       | Percentage of maximum capacity being utilized (actual production divided by maximum power).                                                                              | %      |
| `Thermal: Production cost ($)`   | Total production cost for each thermal generator (minimum power cost plus variable costs).                                                                               | $      |
| `Thermal: Startup cost ($)`      | Startup cost incurred by each thermal generator at each time period.                                                                                                     | $      |
| `Thermal: Shutdown cost ($)`     | Shutdown cost incurred by each thermal generator at each time period.                                                                                                    | $      |
| `Thermal: Is on`                 | Commitment status (1 if generator is on, 0 if off).                                                                                                                      | Binary |
| `Thermal: Switch on`             | Switch-on indicator (1 if generator starts up at this time step, 0 otherwise).                                                                                           | Binary |
| `Thermal: Switch off`            | Switch-off indicator (1 if generator shuts down at this time step, 0 otherwise).                                                                                         | Binary |
| `Thermal: Gross revenue ($)`     | Revenue obtained from selling power at LMP (production times LMP). Only available if LMPs are computed.                                                                  | $      |
| `Thermal: Net revenue ($)`       | Net revenue after subtracting production, startup and shutdown costs from gross revenue. Only available if LMPs are computed.                                            | $      |
| `Thermal: Uplift payment ($)`    | Make-whole payment needed to cover negative net revenue (zero if net revenue is positive). Only available if LMPs are computed.                                          | $      |
| `Thermal: Reactive power (MVAr)` | Reactive power output from each thermal generator. Only present when AC formulation is used.                                                                             | MVAr   |
| `Thermal: Investment status`     | Investment status for candidate thermal units (1 if invested, 0 otherwise). Only included for units with positive investment cost. Value is a scalar, not a time series. | Binary |

## Example

```json
{
  "Thermal: Production (MW)": {
    "g1": [115.0, 120.5, 125.3, 118.7],
    "g2": [0.0, 50.2, 55.8, 53.1]
  },
  "Thermal: Utilization (%)": {
    "g1": [85.19, 89.26, 92.81, 87.93],
    "g2": [0.0, 62.75, 69.75, 66.38]
  },
  "Thermal: Production cost ($)": {
    "g1": [1450.0, 1520.3, 1580.7, 1490.2],
    "g2": [0.0, 750.5, 835.2, 795.8]
  },
  "Thermal: Startup cost ($)": {
    "g1": [0.0, 0.0, 0.0, 0.0],
    "g2": [0.0, 300.0, 0.0, 0.0]
  },
  "Thermal: Shutdown cost ($)": {
    "g1": [0.0, 0.0, 0.0, 0.0],
    "g2": [0.0, 0.0, 0.0, 0.0]
  },
  "Thermal: Is on": {
    "g1": [1.0, 1.0, 1.0, 1.0],
    "g2": [0.0, 1.0, 1.0, 1.0]
  },
  "Thermal: Switch on": {
    "g1": [0.0, 0.0, 0.0, 0.0],
    "g2": [0.0, 1.0, 0.0, 0.0]
  },
  "Thermal: Switch off": {
    "g1": [0.0, 0.0, 0.0, 0.0],
    "g2": [0.0, 0.0, 0.0, 0.0]
  },
  "Thermal: Reactive power (MVAr)": {
    "g1": [25.3, 28.1, 30.5, 26.8],
    "g2": [0.0, 12.4, 15.2, 13.7]
  },
  "Thermal: Gross revenue ($)": {
    "g1": [2875.0, 3012.5, 3132.5, 2967.5],
    "g2": [0.0, 1506.0, 1674.0, 1593.0]
  },
  "Thermal: Net revenue ($)": {
    "g1": [1425.0, 1492.2, 1551.8, 1477.3],
    "g2": [0.0, 455.5, 838.8, 797.2]
  },
  "Thermal: Uplift payment ($)": {
    "g1": 0.0,
    "g2": 0.0
  }
}
```

## Branches

## Shared output keys

| Key                            | Description                                                                                                                                                                                        | Unit    |
| :----------------------------- | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | :------ | ----------------------------------------------------- | --- |
| `Branch: Overflow (MW)`        | Flow limit slack. This is a single variable shared across base-case and contingency constraints; the solver sets it to the minimum value that satisfies all flow limit constraints simultaneously. | MW      |
| `Branch: Overflow penalty ($)` | Penalty cost for overflow (overflow times flow limit penalty per time step).                                                                                                                       | $       |
| `Branch: Base utilization (%)` | Percentage of normal flow limit utilized under base-case conditions. DC: `                                                                                                                         | flow    | / normal limit`. AC: `apparent power / normal limit`. | %   |
| `Branch: Investment cost ($)`  | Total investment cost for the branch (number of circuits times cost per circuit). Only included for branches with positive investment cost. Value is a scalar.                                     | $       |
| `Branch: Investment status`    | Number of parallel circuits invested along each candidate branch corridor. Only included for branches with positive investment cost. Value is a scalar integer.                                    | Integer |

## DC output keys

| Key                                 | Description                                                                                                                                                                    | Unit |
| :---------------------------------- | :----------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | :--- |
| `Branch: Base flow (MW)`            | Pre-contingency active power flow through each branch.                                                                                                                         | MW   |
| `Branch: Contingency flow (MW)`     | Post-contingency active power flow. Nested structure: `contingency → branch → [values]`. Only present when the instance has contingencies.                                     | MW   |
| `Branch: Contingency overflow (MW)` | Amount by which post-contingency flow exceeds the emergency flow limit. Nested structure: `contingency → branch → [values]`. Only present when the instance has contingencies. | MW   |

## AC output keys

| Key                                          | Description                                                                      | Unit |
| :------------------------------------------- | :------------------------------------------------------------------------------- | :--- |
| `Branch: Base active flow from-end (MW)`     | Pre-contingency active power flow at the from-end (source bus) of each branch.   | MW   |
| `Branch: Base reactive flow from-end (MVAr)` | Pre-contingency reactive power flow at the from-end (source bus) of each branch. | MVAr |
| `Branch: Base active flow to-end (MW)`       | Pre-contingency active power flow at the to-end (target bus) of each branch.     | MW   |
| `Branch: Base reactive flow to-end (MVAr)`   | Pre-contingency reactive power flow at the to-end (target bus) of each branch.   | MVAr |

## DC example

```json
{
  "Branch: Base flow (MW)": {
    "l1": [125.3, 130.8, 128.2, 135.5],
    "l2": [-85.7, -92.5, -91.3, -87.3]
  },
  "Branch: Overflow (MW)": {
    "l1": [0.0, 0.0, 0.0, 0.0],
    "l2": [0.0, 2.5, 1.3, 0.0]
  },
  "Branch: Overflow penalty ($)": {
    "l1": [0.0, 0.0, 0.0, 0.0],
    "l2": [0.0, 12500.0, 6500.0, 0.0]
  },
  "Branch: Base utilization (%)": {
    "l1": [83.53, 87.2, 85.47, 90.33],
    "l2": [95.22, 102.78, 101.44, 97.0]
  },
  "Branch: Contingency flow (MW)": {
    "outage l3": {
      "l1": [128.1, 133.5, 131.0, 138.2],
      "l2": [-88.4, -95.2, -94.0, -90.0]
    }
  },
  "Branch: Contingency overflow (MW)": {
    "outage l3": {
      "l1": [0.0, 0.0, 0.0, 0.0],
      "l2": [0.0, 5.2, 4.0, 0.0]
    }
  },
  "Branch: Investment cost ($)": {
    "l3": 3000000.0
  },
  "Branch: Investment status": {
    "l3": 2.0
  }
}
```

## AC example

```json
{
  "Branch: Base active flow from-end (MW)": {
    "l1": [125.3, 130.8, 128.2, 135.5],
    "l2": [-85.7, -92.5, -91.3, -87.3]
  },
  "Branch: Base reactive flow from-end (MVAr)": {
    "l1": [18.2, 19.5, 18.8, 20.1],
    "l2": [-12.3, -14.1, -13.5, -12.8]
  },
  "Branch: Base active flow to-end (MW)": {
    "l1": [-123.8, -129.2, -126.7, -133.9],
    "l2": [86.1, 93.0, 91.8, 87.8]
  },
  "Branch: Base reactive flow to-end (MVAr)": {
    "l1": [-16.5, -17.8, -17.1, -18.4],
    "l2": [13.0, 14.8, 14.2, 13.5]
  },
  "Branch: Overflow (MW)": {
    "l1": [0.0, 0.0, 0.0, 0.0],
    "l2": [0.0, 2.5, 1.3, 0.0]
  },
  "Branch: Overflow penalty ($)": {
    "l1": [0.0, 0.0, 0.0, 0.0],
    "l2": [0.0, 12500.0, 6500.0, 0.0]
  },
  "Branch: Base utilization (%)": {
    "l1": [83.53, 87.2, 85.47, 90.33],
    "l2": [95.22, 102.78, 101.44, 97.0]
  }
}
```

## Interfaces

| Key                               | Description                                                                                                 | Unit |
| :-------------------------------- | :---------------------------------------------------------------------------------------------------------- | :--- |
| `Interface: Flow (MW)`            | Net weighted flow through each interface.                                                                   | MW   |
| `Interface: Overflow (MW)`        | Amount of flow exceeding the interface's flow limits.                                                       | MW   |
| `Interface: Overflow penalty ($)` | Penalty cost incurred for overflow violations on each interface (overflow amount times flow limit penalty). | $    |

## Example

```json
{
  "Interface: Flow (MW)": {
    "ifc1": [85.3, 92.1, 88.7, 95.2],
    "ifc2": [48.5, 55.2, 57.8, 53.1]
  },
  "Interface: Overflow (MW)": {
    "ifc1": [0.0, 0.0, 0.0, 0.0],
    "ifc2": [0.0, 0.0, 0.0, 0.0]
  },
  "Interface: Overflow penalty ($)": {
    "ifc1": [0.0, 0.0, 0.0, 0.0],
    "ifc2": [0.0, 0.0, 0.0, 0.0]
  }
}
```

## Price-Sensitive Loads

| Key                                        | Description                                                                                                       | Unit |
| :----------------------------------------- | :---------------------------------------------------------------------------------------------------------------- | :--- |
| `Price-sensitive load: Demand served (MW)` | Amount of price-sensitive load demand served at each bus.                                                         | MW   |
| `Price-sensitive load: Expense ($)`        | Expense incurred for serving price-sensitive load (demand served times LMP). Only available if LMPs are computed. | $    |

## Example

```json
{
  "Price-sensitive load: Demand served (MW)": {
    "p1": [45.5, 48.2, 50.0, 47.8],
    "p2": [30.0, 30.0, 28.5, 30.0]
  },
  "Price-sensitive load: Expense ($)": {
    "p1": [1137.5, 1205.0, 1250.0, 1195.0],
    "p2": [900.0, 900.0, 855.0, 900.0]
  }
}
```

## Virtual Transactions

| Key                     | Description                                                                                                          | Unit |
| :---------------------- | :------------------------------------------------------------------------------------------------------------------- | :--- |
| `Virtual: Cleared (MW)` | Amount of each virtual transaction cleared in the market.                                                            | MW   |
| `Virtual: Revenue ($)`  | Revenue from each virtual transaction (positive for profit, negative for loss). Only available if LMPs are computed. | $    |

## Example

```json
{
  "Virtual: Cleared (MW)": {
    "vt_inc1": [50.0, 50.0, 50.0, 50.0],
    "vt_dec1": [40.0, 40.0, 40.0, 40.0],
    "vt_utc1": [30.0, 30.0, 30.0, 30.0]
  },
  "Virtual: Revenue ($)": {
    "vt_inc1": [1250.0, 1250.0, 1250.0, 1250.0],
    "vt_dec1": [-1200.0, -1200.0, -1200.0, -1200.0],
    "vt_utc1": [150.0, 150.0, 150.0, 150.0]
  }
}
```

## Profiled Generators

| Key                               | Description                                                                                                                                                               | Unit   |
| :-------------------------------- | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | :----- |
| `Profiled: Production (MW)`       | Power output from each profiled generator (renewables, hydro, etc.).                                                                                                      | MW     |
| `Profiled: Utilization (%)`       | Percentage of maximum capacity being utilized (actual production divided by maximum power).                                                                               | %      |
| `Profiled: Production cost ($)`   | Production cost for each profiled generator (output times cost).                                                                                                          | $      |
| `Profiled: Gross revenue ($)`     | Revenue obtained from selling power at LMP (production times LMP). Only available if LMPs are computed.                                                                   | $      |
| `Profiled: Net revenue ($)`       | Net revenue after subtracting production costs from gross revenue. Only available if LMPs are computed.                                                                   | $      |
| `Profiled: Uplift payment ($)`    | Make-whole payment needed to cover negative net revenue (zero if net revenue is positive). Only available if LMPs are computed.                                           | $      |
| `Profiled: Reactive power (MVAr)` | Reactive power output from each profiled generator. Only present when AC formulation is used.                                                                             | MVAr   |
| `Profiled: Investment status`     | Investment status for candidate profiled units (1 if invested, 0 otherwise). Only included for units with positive investment cost. Value is a scalar, not a time series. | Binary |

## Example

```json
{
  "Profiled: Production (MW)": {
    "wind1": [85.3, 92.1, 88.7, 95.2],
    "solar1": [0.0, 10.5, 45.8, 78.3]
  },
  "Profiled: Utilization (%)": {
    "wind1": [85.3, 92.1, 88.7, 95.2],
    "solar1": [0.0, 10.5, 45.8, 78.3]
  },
  "Profiled: Production cost ($)": {
    "wind1": [85.3, 92.1, 88.7, 95.2],
    "solar1": [0.0, 10.5, 45.8, 78.3]
  },
  "Profiled: Reactive power (MVAr)": {
    "wind1": [0.0, 0.0, 0.0, 0.0],
    "solar1": [0.0, 0.0, 0.0, 0.0]
  },
  "Profiled: Gross revenue ($)": {
    "wind1": [2132.5, 2302.5, 2217.5, 2380.0],
    "solar1": [0.0, 262.5, 1145.0, 1957.5]
  },
  "Profiled: Net revenue ($)": {
    "wind1": [2047.2, 2210.4, 2128.8, 2284.8],
    "solar1": [0.0, 252.0, 1099.2, 1879.2]
  },
  "Profiled: Uplift payment ($)": {
    "wind1": 0.0,
    "solar1": 0.0
  }
}
```

## Storage Units

| Key                              | Description                                                                                                                                                              | Unit   |
| :------------------------------- | :----------------------------------------------------------------------------------------------------------------------------------------------------------------------- | :----- |
| `Storage: Level (MWh)`           | Energy level stored in each storage unit.                                                                                                                                | MWh    |
| `Storage: Is charging`           | Charging indicator (1 if storage unit is charging, 0 otherwise).                                                                                                         | Binary |
| `Storage: Charging rate (MW)`    | Power rate at which each storage unit is charging.                                                                                                                       | MW     |
| `Storage: Charging cost ($)`     | Cost incurred for charging each storage unit (rate times cost).                                                                                                          | $      |
| `Storage: Is discharging`        | Discharging indicator (1 if storage unit is discharging, 0 otherwise).                                                                                                   | Binary |
| `Storage: Discharging rate (MW)` | Power rate at which each storage unit is discharging.                                                                                                                    | MW     |
| `Storage: Discharging cost ($)`  | Cost incurred for discharging each storage unit (rate times cost).                                                                                                       | $      |
| `Storage: Reactive power (MVAr)` | Reactive power output from each storage unit. Only present when AC formulation is used.                                                                                  | MVAr   |
| `Storage: Investment status`     | Investment status for candidate storage units (1 if invested, 0 otherwise). Only included for units with positive investment cost. Value is a scalar, not a time series. | Binary |

## Example

```json
{
  "Storage: Level (MWh)": {
    "su1": [70.0, 65.5, 72.3, 68.9],
    "su2": [50.0, 60.0, 55.0, 58.0]
  },
  "Storage: Is charging": {
    "su1": [0.0, 0.0, 1.0, 0.0],
    "su2": [1.0, 1.0, 0.0, 1.0]
  },
  "Storage: Charging rate (MW)": {
    "su1": [0.0, 0.0, 8.5, 0.0],
    "su2": [10.0, 10.0, 0.0, 5.0]
  },
  "Storage: Charging cost ($)": {
    "su1": [0.0, 0.0, 17.0, 0.0],
    "su2": [30.0, 30.0, 0.0, 15.0]
  },
  "Storage: Is discharging": {
    "su1": [1.0, 1.0, 0.0, 1.0],
    "su2": [0.0, 0.0, 1.0, 0.0]
  },
  "Storage: Discharging rate (MW)": {
    "su1": [5.0, 4.5, 0.0, 3.4],
    "su2": [0.0, 0.0, 5.0, 0.0]
  },
  "Storage: Discharging cost ($)": {
    "su1": [12.5, 11.25, 0.0, 8.5],
    "su2": [0.0, 0.0, 17.5, 0.0]
  },
  "Storage: Reactive power (MVAr)": {
    "su1": [2.5, 2.3, -1.8, 2.1],
    "su2": [-3.0, -3.0, 1.5, -2.5]
  }
}
```

## Reserves

| Key                       | Description                                                                                                                                                                              | Unit |
| :------------------------ | :--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | :--- |
| `Reserve: Provided (MW)`  | Amount of reserve provided by each eligible thermal generator for each reserve product (both spinning and non-spinning). Nested structure: `reserve_name -> generator_name -> [values]`. | MW   |
| `Reserve: Shortfall (MW)` | Amount of reserve requirement not met for each reserve product.                                                                                                                          | MW   |

## Example

```json
{
  "Reserve: Provided (MW)": {
    "r1": {
      "g1": [15.0, 18.5, 16.2, 17.8],
      "g2": [0.0, 5.5, 6.8, 7.2]
    }
  },
  "Reserve: Shortfall (MW)": {
    "r1": [0.0, 0.0, 0.0, 0.0]
  }
}
```

## Summary

Each scenario includes a `Summary` section containing aggregated scalar metrics
computed from the solution. Values are rounded to two decimal places and sorted
alphabetically by key. The summary is automatically populated by each component
extension; which keys appear depends on which components are present in the
instance and whether LMPs are computed. Below is the full set of possible keys.

## Bus & load

| Key                                 | Description                                                      | Unit |
| :---------------------------------- | :--------------------------------------------------------------- | :--- |
| `Bus: System peak load (MW)`        | Maximum total fixed load across all buses over the time horizon. | MW   |
| `Bus: System minimum load (MW)`     | Minimum total fixed load across all buses over the time horizon. | MW   |
| `Bus: Total load curtailment (MW)`  | Sum of load curtailment across all buses and time steps.         | MW   |
| `Bus: Peak load curtailment (MW)`   | Maximum total load curtailment in any single time step.          | MW   |
| `Bus: Total fixed load expense ($)` | Total expense for serving fixed load (requires LMPs).            | $    |

## Solver

| Key                              | Description                                                 | Unit |
| :------------------------------- | :---------------------------------------------------------- | :--- |
| `Solver: Objective value ($)`    | Objective function value from the solver.                   | $    |
| `Solver: Objective bound`        | Best bound on the objective (if available from the solver). | $    |
| `Solver: Optimality gap (%)`     | Relative MIP gap (if available from the solver).            | %    |
| `Solver: Solve time (s)`         | Wall-clock solve time reported by the solver.               | s    |
| `Solver: Termination status`     | JuMP termination status string (e.g., `"OPTIMAL"`).         | ---  |
| `Solver: Has load curtailment?`  | Whether any load curtailment is present.                    | Bool |
| `Solver: Has branch overflow?`   | Whether any branch overflow is present.                     | Bool |
| `Solver: Has reserve shortfall?` | Whether any reserve shortfall is present.                   | Bool |

## Reserves

| Key                              | Description                                                   | Unit |
| :------------------------------- | :------------------------------------------------------------ | :--- |
| `Reserve: Peak shortfall (MW)`   | Maximum reserve shortfall across all reserves and time steps. | MW   |

## Thermal generators

| Key                                  | Description                                                             | Unit |
| :----------------------------------- | :---------------------------------------------------------------------- | :--- |
| `Thermal: Total production cost ($)` | Sum of production costs across all thermal units and time steps.        | $    |
| `Thermal: Total startup cost ($)`    | Sum of startup costs across all thermal units and time steps.           | $    |
| `Thermal: Total shutdown cost ($)`   | Sum of shutdown costs across all thermal units and time steps.          | $    |
| `Thermal: Peak production (MW)`      | Maximum total thermal production in any single time step.               | MW   |
| `Thermal: Peak capacity online (MW)` | Maximum total online thermal capacity in any single time step.          | MW   |
| `Thermal: Average utilization (%)`   | Production divided by online capacity, averaged over all time steps.    | %    |
| `Thermal: Total startups`            | Total number of generator startups.                                     | Int  |
| `Thermal: Total shutdowns`           | Total number of generator shutdowns.                                    | Int  |
| `Thermal: Total investment cost ($)` | Sum of investment costs for invested thermal units (if any candidates). | $    |
| `Thermal: Units invested`            | Number of thermal candidate units invested (if any candidates).         | Int  |

## Branches

| Key                                 | Description                                                                  | Unit |
| :---------------------------------- | :--------------------------------------------------------------------------- | :--- |
| `Branch: Branches with overflow`    | Number of branches experiencing overflow in at least one time step.          | Int  |
| `Branch: Congested branches`        | Number of branches with utilization reaching 100% in at least one time step. | Int  |
| `Branch: Peak total overflow (MW)`  | Maximum total overflow across all branches in any single time step.          | MW   |
| `Branch: Total investment cost ($)` | Sum of branch investment costs (if any candidates).                          | $    |
| `Branch: Circuits invested`         | Number of candidate branches with at least one circuit invested (if any candidates). | Int  |

## Interfaces

| Key                                   | Description                                               | Unit |
| :------------------------------------ | :-------------------------------------------------------- | :--- |
| `Interface: Peak total overflow (MW)` | Maximum total interface overflow in any single time step. | MW   |

## Profiled generators

| Key                                   | Description                                                              | Unit |
| :------------------------------------ | :----------------------------------------------------------------------- | :--- |
| `Profiled: Total production cost ($)` | Sum of production costs across all profiled units and time steps.        | $    |
| `Profiled: Total curtailment (MW)`    | Total available energy minus total produced energy.                      | MW   |
| `Profiled: Utilization (%)`           | Percentage of total available energy that was produced.                  | %    |
| `Profiled: Total investment cost ($)` | Sum of investment costs for invested profiled units (if any candidates). | $    |
| `Profiled: Units invested`            | Number of profiled candidate units invested (if any candidates).         | Int  |

## Storage units

| Key                                      | Description                                                                                      | Unit |
| :--------------------------------------- | :----------------------------------------------------------------------------------------------- | :--- |
| `Storage: Total cost ($)`                | Sum of charging and discharging costs across all storage units.                                  | $    |
| `Storage: Total energy charged (MWh)`    | Total energy charged (MW times time step duration).                                              | MWh  |
| `Storage: Total energy discharged (MWh)` | Total energy discharged (MW times time step duration).                                           | MWh  |
| `Storage: Round-trip loss (MWh)`         | Energy lost to round-trip inefficiency (charged minus discharged minus change in stored energy). | MWh  |
| `Storage: Peak charging rate (MW)`       | Maximum total charging rate in any single time step.                                             | MW   |
| `Storage: Peak discharging rate (MW)`    | Maximum total discharging rate in any single time step.                                          | MW   |
| `Storage: Total investment cost ($)`     | Sum of investment costs for invested storage units (if any candidates).                          | $    |
| `Storage: Units invested`                | Number of storage candidate units invested (if any candidates).                                  | Int  |

## Price-sensitive loads

| Key                                              | Description                                                           | Unit |
| :----------------------------------------------- | :-------------------------------------------------------------------- | :--- |
| `Price-sensitive load: Total demand served (MW)` | Sum of price-sensitive demand served across all units and time steps. | MW   |
| `Price-sensitive load: Total expense ($)`        | Total expense for price-sensitive loads (requires LMPs).              | $    |

## Virtual transactions

| Key                               | Description                                                 | Unit |
| :-------------------------------- | :---------------------------------------------------------- | :--- |
| `Virtual: Total INC cleared (MW)` | Total INC virtual transaction volume cleared.               | MW   |
| `Virtual: Total DEC cleared (MW)` | Total DEC virtual transaction volume cleared.               | MW   |
| `Virtual: Total UTC cleared (MW)` | Total UTC virtual transaction volume cleared.               | MW   |
| `Virtual: Net objective cost ($)` | Net cost of virtual transactions in the objective function. | $    |
| `Virtual: Total revenue ($)`      | Total revenue from virtual transactions (requires LMPs).    | $    |

## Flexiramp reserves

| Key                                   | Description                                                          | Unit |
| :------------------------------------ | :------------------------------------------------------------------- | :--- |
| `Flexiramp: Peak up shortfall (MW)`   | Maximum up-flexiramp shortfall across all reserves and time steps.   | MW   |
| `Flexiramp: Peak down shortfall (MW)` | Maximum down-flexiramp shortfall across all reserves and time steps. | MW   |
| `Flexiramp: Has shortfall?`           | Whether any flexiramp shortfall exceeds the tolerance.               | Bool |

## Penalties

| Key                                     | Description                                 | Unit |
| :-------------------------------------- | :------------------------------------------ | :--- |
| `Total penalty: Load curtailment ($)`   | Total penalty cost from load curtailment.   | $    |
| `Total penalty: Reserve shortfall ($)`  | Total penalty cost from reserve shortfalls. | $    |
| `Total penalty: Branch overflow ($)`    | Total penalty cost from branch overflow.    | $    |
| `Total penalty: Interface overflow ($)` | Total penalty cost from interface overflow. | $    |

## LMP statistics

| Key                    | Description                                                  | Unit  |
| :--------------------- | :----------------------------------------------------------- | :---- |
| `LMP: Average ($/MWh)` | Load-weighted average LMP across all buses (requires LMPs).  | $/MWh |
| `LMP: Peak ($/MWh)`    | Maximum LMP across all buses and time steps (requires LMPs). | $/MWh |
| `LMP: Minimum ($/MWh)` | Minimum LMP across all buses and time steps (requires LMPs). | $/MWh |

## Example

```json
{
  "Summary": {
    "Branch: Branches with overflow": 1,
    "Branch: Congested branches": 1,
    "Branch: Peak total overflow (MW)": 2.5,
    "Bus: Peak load curtailment (MW)": 0.0,
    "Bus: System minimum load (MW)": 120.5,
    "Bus: System peak load (MW)": 185.3,
    "Bus: Total fixed load expense ($)": 15000.0,
    "Bus: Total load curtailment (MW)": 0.0,
    "LMP: Average ($/MWh)": 27.35,
    "LMP: Minimum ($/MWh)": 25.0,
    "LMP: Peak ($/MWh)": 30.0,
    "Profiled: Total curtailment (MW)": 15.2,
    "Profiled: Total production cost ($)": 425.8,
    "Profiled: Utilization (%)": 85.3,
    "Solver: Has branch overflow?": true,
    "Solver: Has load curtailment?": false,
    "Solver: Objective value ($)": 48250.0,
    "Solver: Solve time (s)": 1.25,
    "Solver: Termination status": "OPTIMAL",
    "Thermal: Average utilization (%)": 78.5,
    "Thermal: Peak capacity online (MW)": 215.0,
    "Thermal: Peak production (MW)": 175.8,
    "Thermal: Total production cost ($)": 6041.2,
    "Thermal: Total shutdowns": 0,
    "Thermal: Total startup cost ($)": 300.0,
    "Thermal: Total startups": 1,
    "Total penalty: Branch overflow ($)": 19000.0,
    "Total penalty: Load curtailment ($)": 0.0
  }
}
```

## Notes

- Investment status variables show whether the unit/line is built (a scalar
  value, not a time series).
- Reserve variables use a nested structure where the outer object is indexed by
  reserve product name, and the inner object is indexed by generator name.
- Components with zero investment cost do not appear in the investment status
  fields.
- Empty collections (e.g., no storage units in the instance) result in empty
  objects for that component type.
