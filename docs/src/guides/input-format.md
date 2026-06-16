# Input data format


An instance of the stochastic security-constrained unit commitment (SCUC)
problem is composed multiple scenarios. Each scenario should be described in an
individual JSON file containing the main section belows. For deterministic
instances, a single scenario file, following the same format below, may also be
provided. Fields that are allowed to differ among scenarios are marked as
"uncertain". Fields that are allowed to be time-dependent are marked as "time
series".

**Mixed-unit convention.** This format uses a mixed-unit convention: active and
reactive power quantities are expressed in MW and MVAr, respectively, while
impedance, admittance, voltage, and tap-ratio quantities are expressed in per
unit (p.u.) on the system `Base MVA`.

- [Parameters](#Parameters)
- [Buses](#Buses)
- [Generators](#Generators)
- [Storage units](#Storage-units)
- [Price-sensitive loads](#Price-sensitive-loads)
- [Virtual transactions](#Virtual-transactions)
- [Branches](#Branches)
- [Shunt devices](#Shunt-devices)
- [Interfaces](#Interfaces)
- [Reserves](#Reserves)
- [Contingencies](#Contingencies)

Each section is described in detail below. See
[case118/2017-01-01.json.gz](https://axavier.org/UnitCommitment.jl/0.5/instances/matpower/case118/2017-01-01.json.gz)
for a complete example.

## Parameters

This section describes system-wide parameters, such as power balance penalty,
and optimization parameters, such as the length of the planning horizon and the
time.

| Key                                        | Description                                                                                                                                                                                                                          | Default  | Time series? | Uncertain? |
| :----------------------------------------- | :----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | :------: | :----------: | :--------: |
| `Version`                                  | Version of UnitCommitment.jl this file was written for. Required to ensure that the file remains readable in future versions of the package. If you are following this page to construct the file, this field should equal `0.5`.    | Required |      No      |     No     |
| `Base MVA`                                 | System-wide base apparent power (in MVA) used for per-unit conversion of impedance, admittance, and voltage quantities.                                                                                                              | Required |      No      |     No     |
| `Time horizon (min)` or `Time horizon (h)` | Length of the planning horizon (in minutes or hours). Either `Time horizon (min)` or `Time horizon (h)` is required, but not both.                                                                                                   | Required |      No      |     No     |
| `Time step (min)`                          | Length of each time step (in minutes). Must be a divisor of 60 (e.g. 60, 30, 20, 15, etc).                                                                                                                                           |   `60`   |      No      |     No     |
| `Power balance penalty ($/MW)`             | Penalty for system-wide shortage or surplus in production (in $/MW). This is charged per time step. For example, if there is a shortage of 1 MW for three time steps, three times this amount will be charged. Negative value implies power balance constraints must always be satisfied (hard constraints). No slack variables are created. | `1000.0` |      No      |    Yes     |
| `Scenario name`                            | Name of the scenario.                                                                                                                                                                                                                |  `"s1"`  |      No      |    ---     |
| `Scenario weight`                          | Weight of the scenario. The scenario weight can be any positive real number, that is, it does not have to be between zero and one. The package normalizes the weights to ensure that the probability of all scenarios sum up to one. |  `1.0`   |      No      |    ---     |
| `Investment cost weight`                   | Weighting factor applied to investment costs. For transmission expansion planning problems, this can be used to scale investment costs relative to operation costs (e.g., convert one-time investment costs to hourly).              |  `1.0`   |      No      |    ---     |

## Example

```json
{
  "Parameters": {
    "Version": "0.5",
    "Base MVA": 100.0,
    "Time horizon (h)": 4,
    "Power balance penalty ($/MW)": 1000.0,
    "Scenario name": "s1",
    "Scenario weight": 0.5,
    "Investment cost weight": 1.0
  }
}
```

## Buses

This section describes the characteristics of each bus in the system.

| Key                          | Description                                                                                                  | Default  | Time series? | Uncertain? |
| :--------------------------- | :----------------------------------------------------------------------------------------------------------- | :------: | :----------: | :--------: |
| `Load (MW)`                  | Fixed active load connected to the bus (in MW).                                                              | Required |     Yes      |    Yes     |
| `Load (MVAr)`                | Fixed reactive load connected to the bus (in MVAr).                                                          |  `0.0`   |     Yes      |    Yes     |
| `Minimum voltage (p.u.)`     | Lower bound on the voltage magnitude at this bus (in per unit).                                              |  `-inf`  |      No      |    Yes     |
| `Maximum voltage (p.u.)`     | Upper bound on the voltage magnitude at this bus (in per unit).                                              |  `+inf`  |      No      |    Yes     |
| `Bus type`                   | Bus classification: `"PQ"` (load bus), `"PV"` (generator bus with voltage control), or `"Slack"` (reference). | `"PQ"`  |      No      |     No     |

## Example

```json
{
  "Buses": {
    "b1": {
      "Load (MW)": 0.0,
      "Load (MVAr)": 0.0,
      "Bus type": "Slack"
    },
    "b2": {
      "Load (MW)": [26.01527, 24.46212, 23.29725, 22.90897],
      "Load (MVAr)": [8.50, 7.95, 7.60, 7.45],
      "Minimum voltage (p.u.)": 0.95,
      "Maximum voltage (p.u.)": 1.05
    }
  }
}
```

## Generators

This section describes all generators in the system. Two types of units can be
specified:

- **Thermal units:** Units that produce power by converting heat into electrical
  energy, such as coal and oil power plants. These units use a more complex
  model, with binary decision variables, and various constraints to enforce ramp
  rates and minimum up/down time.
- **Profiled units:** Simplified model for units that do not require the
  constraints mentioned above, only a maximum and minimum power output for each
  time period. Typically used for renewables and hydro.

## Thermal Units

| Key                                                          | Description                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        | Default           | Time series? | Uncertain? |
| :----------------------------------------------------------- | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------- | :----------: | :--------: |
| `Bus`                                                        | Identifier of the bus where this generator is located (string).                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    | Required          |      No      |    Yes     |
| `Type`                                                       | Type of the generator (string). For thermal generators, this must be `Thermal`.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    | Required          |      No      |     No     |
| `Production cost curve (MW)` and `Production cost curve ($)` | Parameters describing the piecewise-linear production costs. See below for more details.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           | Required          |     Yes      |    Yes     |
| `Startup costs ($)` and `Startup delays (h)`                 | Parameters describing how much it costs to start the generator after it has been shut down for a certain amount of time. If `Startup costs ($)` and `Startup delays (h)` are set to `[300.0, 400.0]` and `[1, 4]`, for example, and the generator is shut down at time `00:00` (h:min), then it costs \$300 to start up the generator at any time between `01:00` and `03:59`, and \$400 to start the generator at time `04:00` or any time after that. The number of startup cost points is unlimited, and may be different for each generator. Startup delays must be strictly increasing and the first entry must equal `Minimum downtime (h)`. | `[0.0]` and `[1]` |      No      |    Yes     |
| `Shutdown cost ($)`                                          | Cost incurred each time the generator shuts down.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  | `0.0`             |      No      |    Yes     |
| `Minimum uptime (h)`                                         | Minimum amount of time the generator must stay operational after starting up (in hours). For example, if the generator starts up at time `00:00` (h:min) and `Minimum uptime (h)` is set to 4, then the generator can only shut down at time `04:00`.                                                                                                                                                                                                                                                                                                                                                                                              | `1`               |      No      |    Yes     |
| `Minimum downtime (h)`                                       | Minimum amount of time the generator must stay offline after shutting down (in hours). For example, if the generator shuts down at time `00:00` (h:min) and `Minimum downtime (h)` is set to 4, then the generator can only start producing power again at time `04:00`.                                                                                                                                                                                                                                                                                                                                                                           | `1`               |      No      |    Yes     |
| `Ramp up limit (MW)`                                         | Maximum increase in production from one time step to the next (in MW). For example, if the generator is producing 100 MW at time step 1 and if this parameter is set to 40 MW, then the generator will produce at most 140 MW at time step 2.                                                                                                                                                                                                                                                                                                                                                                                                      | `+inf`            |      No      |    Yes     |
| `Ramp down limit (MW)`                                       | Maximum decrease in production from one time step to the next (in MW). For example, if the generator is producing 100 MW at time step 1 and this parameter is set to 40 MW, then the generator will produce at least 60 MW at time step 2.                                                                                                                                                                                                                                                                                                                                                                                                         | `+inf`            |      No      |    Yes     |
| `Startup limit (MW)`                                         | Maximum amount of power a generator can produce immediately after starting up (in MW). For example, if `Startup limit (MW)` is set to 100 MW and the unit is off at time step 1, then it may produce at most 100 MW at time step 2.                                                                                                                                                                                                                                                                                                                                                                                                                | `+inf`            |      No      |    Yes     |
| `Shutdown limit (MW)`                                        | Maximum amount of power a generator can produce immediately before shutting down (in MW). Specifically, the generator can only shut down at time step `t+1` if its production at time step `t` is below this limit.                                                                                                                                                                                                                                                                                                                                                                                                                                | `+inf`            |      No      |    Yes     |
| `Initial status (h)`                                         | If set to a positive number, indicates the amount of time (in hours) the generator has been on at the beginning of the simulation, and if set to a negative number, the amount of time the generator has been off. For example, if `Initial status (h)` is `-2`, this means that the generator was off since `-02:00` (h:min). The simulation starts at time `00:00`. If `Initial status (h)` is `3`, this means that the generator was on since `-03:00`. A value of zero is not acceptable.                                                                                                                                                      | Required          |      No      |     No     |
| `Initial power (MW)`                                         | Amount of power the generator at time step `-1`, immediately before the planning horizon starts.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   | Required          |      No      |     No     |
| `Must run?`                                                  | If `true`, the generator should be committed, even if that is not economical (Boolean).                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            | `false`           |     Yes      |    Yes     |
| `Reserve eligibility`                                        | List of reserve products (spinning or non-spinning) this generator is eligible to provide. By default, the generator is not eligible to provide any reserves.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      | `[]`              |      No      |    Yes     |
| `Non-spinning reserve capacity (MW)`                         | Maximum reserve contribution when the generator is offline (in MW).                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                | `0.0`             |      No      |    Yes     |
| `Commitment status`                                          | List of commitment status over the time horizon. At time `t`, if `true`, the generator must be committed at that time period; if `false`, the generator must not be committed at that time period. If `null` at time `t`, the generator's commitment status is then decided by the model. By default, the status is a list of `null` values.                                                                                                                                                                                                                                                                                                       | `null`            |     Yes      |    Yes     |
| `Investment cost ($)`                                        | Cost to build a candidate generation unit. Should be zero for existing units.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      | `0.0`             |      No      |     No     |
| `Minimum reactive power (MVAr)`                                  | Minimum reactive power output (in MVAr).                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           | `0.0`             |      No      |    Yes     |
| `Maximum reactive power (MVAr)`                                  | Maximum reactive power output (in MVAr).                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           | `0.0`             |      No      |    Yes     |


## Profiled Units

| Key                   | Description                                                                       | Default  | Time series? | Uncertain? |
| :-------------------- | :-------------------------------------------------------------------------------- | :------: | :----------: | :--------: |
| `Bus`                 | Identifier of the bus where this generator is located (string).                   | Required |      No      |    Yes     |
| `Type`                | Type of the generator (string). For profiled generators, this must be `Profiled`. | Required |      No      |     No     |
| `Cost ($/MW)`         | Cost incurred for serving each MW of power by this generator.                     | Required |     Yes      |    Yes     |
| `Minimum power (MW)`  | Minimum amount of power this generator may supply.                                |  `0.0`   |     Yes      |    Yes     |
| `Maximum power (MW)`  | Maximum amount of power this generator may supply.                                | Required |     Yes      |    Yes     |
| `Investment cost ($)`       | Cost to build a candidate generation unit. Should be zero for existing units.     |  `0.0`.  |      No      |     No     |
| `Minimum reactive power (MVAr)` | Minimum reactive power output (in MVAr).                                          |  `0.0`   |      No      |    Yes     |
| `Maximum reactive power (MVAr)` | Maximum reactive power output (in MVAr).                                          |  `0.0`   |      No      |    Yes     |

## Production costs and limits

Production costs are represented as piecewise-linear curves. Figure 1 shows an
example cost curve with three segments, where it costs \$1400, \$1600, \$2200
and \$2400 to generate, respectively, 100, 110, 130 and 135 MW of power. To
model this generator, `Production cost curve (MW)` should be set to
`[100, 110, 130, 135]`, and `Production cost curve ($)` should be set to
`[1400, 1600, 2200, 2400]`. Note that this curve also specifies the production
limits. Specifically, the first point identifies the minimum power output when
the unit is operational, while the last point identifies the maximum power
output.

```@raw html
<center>
    <img src="../../assets/cost_curve.png" style="max-width: 500px"/>
    <div><b>Figure 1.</b> Piecewise-linear production cost curve.</div>
    <br/>
</center>
```

## Additional remarks:

- For time-dependent production limits or time-dependent production costs, the
  usage of nested arrays is allowed. For example, if
  `Production cost curve (MW)` is set to `[5.0, [10.0, 12.0, 15.0, 20.0]]`, then
  the unit may generate at most 10, 12, 15 and 20 MW of power during time steps
  1, 2, 3 and 4, respectively. The minimum output for all time periods is fixed
  to at 5 MW.
- There is no limit to the number of piecewise-linear segments, and different
  generators may have a different number of segments.
- If `Production cost curve (MW)` and `Production cost curve ($)` both contain a
  single element, then the generator must produce exactly that amount of power
  when operational. To specify that the generator may produce any amount of
  power up to a certain limit `P`, the parameter `Production cost curve (MW)`
  should be set to `[0, P]`.
- Production cost curves must be convex.

## Example

```json
{
  "Generators": {
    "gen1": {
      "Bus": "b1",
      "Type": "Thermal",
      "Production cost curve (MW)": [100.0, 110.0, 130.0, 135.0],
      "Production cost curve ($)": [1400.0, 1600.0, 2200.0, 2400.0],
      "Startup costs ($)": [300.0, 400.0],
      "Startup delays (h)": [1, 4],
      "Ramp up limit (MW)": 232.68,
      "Ramp down limit (MW)": 232.68,
      "Startup limit (MW)": 232.68,
      "Shutdown limit (MW)": 232.68,
      "Shutdown cost ($)": 150.0,
      "Minimum downtime (h)": 4,
      "Minimum uptime (h)": 4,
      "Initial status (h)": 12,
      "Initial power (MW)": 115,
      "Must run?": false,
      "Reserve eligibility": ["r1"],
      "Minimum reactive power (MVAr)": -50.0,
      "Maximum reactive power (MVAr)": 80.0
    },
    "gen2": {
      "Bus": "b5",
      "Type": "Thermal",
      "Production cost curve (MW)": [0.0, [10.0, 8.0, 0.0, 3.0]],
      "Production cost curve ($)": [0.0, 0.0],
      "Initial status (h)": -100,
      "Initial power (MW)": 0,
      "Reserve eligibility": ["r1", "r2"],
      "Commitment status": [true, false, null, true]
    },
    "gen3": {
      "Bus": "b6",
      "Type": "Profiled",
      "Minimum power (MW)": 10.0,
      "Maximum power (MW)": 120.0,
      "Cost ($/MW)": 100.0,
      "Investment cost ($)": 3000000.0,
      "Minimum reactive power (MVAr)": 0.0,
      "Maximum reactive power (MVAr)": 0.0
    }
  }
}
```

## Storage units

This section describes energy storage units in the system which charge and
discharge power. The storage units consume power while charging, and generate
power while discharging.

| Key                                           | Description                                                                                                                                                 |        Default        | Time series? | Uncertain? |
| :-------------------------------------------- | :---------------------------------------------------------------------------------------------------------------------------------------------------------- | :-------------------: | :----------: | :--------: |
| `Bus`                                         | Bus where the storage unit is located. Multiple storage units may be placed at the same bus.                                                                |       Required        |      No      |    Yes     |
| `Minimum level (MWh)`                         | Minimum of energy level this storage unit may contain.                                                                                                      |         `0.0`         |     Yes      |    Yes     |
| `Maximum level (MWh)`                         | Maximum of energy level this storage unit may contain.                                                                                                      |       Required        |     Yes      |    Yes     |
| `Allow simultaneous charging and discharging` | If `false`, the storage unit is not allowed to charge and discharge at the same time (Boolean).                                                             |        `true`         |     Yes      |    Yes     |
| `Charge cost ($/MW)`                          | Cost incurred for charging each MW of power into this storage unit.                                                                                         |       Required        |     Yes      |    Yes     |
| `Discharge cost ($/MW)`                       | Cost incurred for discharging each MW of power from this storage unit.                                                                                      |       Required        |     Yes      |    Yes     |
| `Charge efficiency`                           | Efficiency rate to charge power into this storage unit. This value must be greater than or equal to `0.0`, and less than or equal to `1.0`.                 |         `1.0`         |     Yes      |    Yes     |
| `Discharge efficiency`                        | Efficiency rate to discharge power from this storage unit. This value must be greater than or equal to `0.0`, and less than or equal to `1.0`.              |         `1.0`         |     Yes      |    Yes     |
| `Loss factor`                                 | The energy dissipation rate of this storage unit. This value must be greater than or equal to `0.0`, and less than or equal to `1.0`.                       |         `0.0`         |     Yes      |    Yes     |
| `Minimum charge rate (MW)`                    | Minimum amount of power rate this storage unit may charge.                                                                                                  |         `0.0`         |     Yes      |    Yes     |
| `Maximum charge rate (MW)`                    | Maximum amount of power rate this storage unit may charge.                                                                                                  |       Required        |     Yes      |    Yes     |
| `Minimum discharge rate (MW)`                 | Minimum amount of power rate this storage unit may discharge.                                                                                               |         `0.0`         |     Yes      |    Yes     |
| `Maximum discharge rate (MW)`                 | Maximum amount of power rate this storage unit may discharge.                                                                                               |       Required        |     Yes      |    Yes     |
| `Initial level (MWh)`                         | Amount of energy this storage unit at time step `-1`, immediately before the planning horizon starts.                                                       |         `0.0`         |      No      |    Yes     |
| `Last period minimum level (MWh)`             | Minimum of energy level this storage unit may contain in the last time step. By default, this value is the same as the last value of `Minimum level (MWh)`. | `Minimum level (MWh)` |      No      |    Yes     |
| `Last period maximum level (MWh)`             | Maximum of energy level this storage unit may contain in the last time step. By default, this value is the same as the last value of `Maximum level (MWh)`. | `Maximum level (MWh)` |      No      |    Yes     |
| `Investment cost ($)`                         | Cost to build a candidate storage unit. Should be zero for existing units.                                                                                  |        `0.0`.         |      No      |     No     |
| `Minimum reactive power (MVAr)`                   | Minimum reactive power output (in MVAr).                                                                                                                    |         `0.0`         |      No      |    Yes     |
| `Maximum reactive power (MVAr)`                   | Maximum reactive power output (in MVAr).                                                                                                                    |         `0.0`         |      No      |    Yes     |
| `Apparent power limit (MVA)`                  | Inverter or thermal apparent-power rating (in MVA).                                                                                                         |        `+inf`         |      No      |    Yes     |

## Example

```json
{
  "Storage units": {
    "su1": {
      "Bus": "b2",
      "Maximum level (MWh)": 100.0,
      "Charge cost ($/MW)": 2.0,
      "Discharge cost ($/MW)": 2.5,
      "Maximum charge rate (MW)": 10.0,
      "Maximum discharge rate (MW)": 8.0,
      "Minimum reactive power (MVAr)": -5.0,
      "Maximum reactive power (MVAr)": 5.0,
      "Apparent power limit (MVA)": 12.0
    },
    "su2": {
      "Bus": "b2",
      "Minimum level (MWh)": 10.0,
      "Maximum level (MWh)": 100.0,
      "Allow simultaneous charging and discharging": false,
      "Charge cost ($/MW)": 3.0,
      "Discharge cost ($/MW)": 3.5,
      "Charge efficiency": 0.8,
      "Discharge efficiency": 0.85,
      "Loss factor": 0.01,
      "Minimum charge rate (MW)": 5.0,
      "Maximum charge rate (MW)": 10.0,
      "Minimum discharge rate (MW)": 2.0,
      "Maximum discharge rate (MW)": 10.0,
      "Initial level (MWh)": 70.0,
      "Last period minimum level (MWh)": 80.0,
      "Last period maximum level (MWh)": 85.0,
      "Investment cost ($)": 2300000.0
    },
    "su3": {
      "Bus": "b9",
      "Minimum level (MWh)": [10.0, 11.0, 12.0, 13.0],
      "Maximum level (MWh)": [100.0, 110.0, 120.0, 130.0],
      "Allow simultaneous charging and discharging": [false, false, true, true],
      "Charge cost ($/MW)": [2.0, 2.1, 2.2, 2.3],
      "Discharge cost ($/MW)": [1.0, 1.1, 1.2, 1.3],
      "Charge efficiency": [0.8, 0.81, 0.82, 0.82],
      "Discharge efficiency": [0.85, 0.86, 0.87, 0.88],
      "Loss factor": [0.01, 0.01, 0.02, 0.02],
      "Minimum charge rate (MW)": [5.0, 5.1, 5.2, 5.3],
      "Maximum charge rate (MW)": [10.0, 10.1, 10.2, 10.3],
      "Minimum discharge rate (MW)": [4.0, 4.1, 4.2, 4.3],
      "Maximum discharge rate (MW)": [8.0, 8.1, 8.2, 8.3],
      "Initial level (MWh)": 20.0,
      "Last period minimum level (MWh)": 21.0,
      "Last period maximum level (MWh)": 22.0
    }
  }
}
```

## Price-sensitive loads

This section describes components in the system which may increase or reduce
their energy consumption according to the energy prices. Fixed loads (as
described in the `buses` section) are always served, regardless of the price,
unless there is significant congestion in the system or insufficient production
capacity. Price-sensitive loads, on the other hand, are only served if it is
economical to do so.

| Key              | Description                                                                                  | Default  | Time series? | Uncertain? |
| :--------------- | :------------------------------------------------------------------------------------------- | :------: | :----------: | :--------: |
| `Bus`            | Bus where the load is located. Multiple price-sensitive loads may be placed at the same bus. | Required |      No      |    Yes     |
| `Revenue ($/MW)` | Revenue obtained for serving each MW of power to this load.                                  | Required |     Yes      |    Yes     |
| `Demand (MW)`    | Maximum amount of power required by this load. Any amount lower than this may be served.     | Required |     Yes      |    Yes     |

## Example

```json
{
  "Price-sensitive loads": {
    "p1": {
      "Bus": "b3",
      "Revenue ($/MW)": 23.0,
      "Demand (MW)": 50.0
    }
  }
}
```

## Virtual transactions

This section describes virtual bids and offers that participate in the day-ahead
market clearing. Three types are supported:

- **INC:** A virtual supply offer at a single bus. If cleared, the virtual
  supply injects power at the specified bus.
- **DEC:** A virtual demand bid at a single bus. If cleared, the virtual demand
  withdraws power at the specified bus.
- **UTC:** A paired injection/withdrawal between a source bus and a sink bus.

## INC / DEC fields

| Key                     | Description                                                 | Default  | Time series? | Uncertain? |
| :---------------------- | :---------------------------------------------------------- | :------: | :----------: | :--------: |
| `Type`                  | Type of virtual transaction. Must be `INC` or `DEC`.        | Required |      No      |     No     |
| `Bus`                   | Bus where the virtual transaction is located.               | Required |      No      |    Yes     |
| `Offer price ($/MW)`    | Price at which the INC offer is willing to sell (INC only). | Required |     Yes      |    Yes     |
| `Bid price ($/MW)`      | Price at which the DEC bid is willing to buy (DEC only).    | Required |     Yes      |    Yes     |
| `Maximum quantity (MW)` | Maximum amount of power that may be cleared.                | Required |     Yes      |    Yes     |

## UTC fields

| Key                     | Description                                            | Default  | Time series? | Uncertain? |
| :---------------------- | :----------------------------------------------------- | :------: | :----------: | :--------: |
| `Type`                  | Type of virtual transaction. Must be `UTC`.            | Required |      No      |     No     |
| `Source bus`            | Bus where the virtual injection occurs.                | Required |      No      |    Yes     |
| `Sink bus`              | Bus where the virtual withdrawal occurs.               | Required |      No      |    Yes     |
| `Bid price ($/MW)`      | Price the UTC trader is willing to pay for the spread. | Required |     Yes      |    Yes     |
| `Maximum quantity (MW)` | Maximum amount of power that may be cleared.           | Required |     Yes      |    Yes     |

## Example

```json
{
  "Virtual transactions": {
    "vt_inc1": {
      "Type": "INC",
      "Bus": "b1",
      "Offer price ($/MW)": 30.0,
      "Maximum quantity (MW)": 50.0
    },
    "vt_dec1": {
      "Type": "DEC",
      "Bus": "b3",
      "Bid price ($/MW)": 60.0,
      "Maximum quantity (MW)": 40.0
    },
    "vt_utc1": {
      "Type": "UTC",
      "Source bus": "b1",
      "Sink bus": "b3",
      "Bid price ($/MW)": 10.0,
      "Maximum quantity (MW)": 30.0
    }
  }
}
```

## Branches

This section describes the characteristics of the transmission system, such as
its topology and the impedance of each transmission line or transformer.

| Key                               | Description                                                                                                                                                                                                                                | Default  | Time series? | Uncertain? |
| :-------------------------------- | :----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | :------: | :----------: | :--------: |
| `Source bus`                       | Identifier of the bus where the transmission line originates.                                                                                                                                                                              | Required |      No      |    Yes     |
| `Target bus`                       | Identifier of the bus where the transmission line reaches.                                                                                                                                                                                 | Required |      No      |    Yes     |
| `Resistance (p.u.)`                | Series resistance of the branch (in per unit on system `Base MVA`).                                                                                                                                                                        |  `0.0`   |      No      |    Yes     |
| `Reactance (p.u.)`                 | Series reactance of the branch (in per unit on system `Base MVA`).                                                                                                                                                                         | Required |      No      |    Yes     |
| `Shunt conductance (p.u.)`         | Total line-charging shunt conductance (in per unit). The full amount is split equally between the two ends of the line in the standard pi-model.                                                                                           |  `0.0`   |      No      |    Yes     |
| `Shunt susceptance (p.u.)`         | Total line-charging shunt susceptance (in per unit). The full amount is split equally between the two ends of the line in the standard pi-model.                                                                                           |  `0.0`   |      No      |    Yes     |
| `Tap ratio (p.u.)`                 | Off-nominal transformer turns ratio (in per unit). A value of `1.0` indicates no transformation.                                                                                                                                          |  `1.0`   |      No      |    Yes     |
| `Phase shift (rad)`                | Transformer phase-shift angle (in radians).                                                                                                                                                                                                |  `0.0`   |      No      |    Yes     |
| `Normal flow limit (MVA)`          | Maximum apparent power (in MVA) allowed to flow through the branch when the system is in its regular, fully-operational state. For candidate lines, this represents the limit per invested circuit.                                        | `+inf`   |     Yes      |    Yes     |
| `Emergency flow limit (MVA)`       | Maximum apparent power (in MVA) allowed to flow through the branch when the system is in degraded state (for example, after the failure of another transmission line). For candidate lines, this represents the limit per invested circuit. | `+inf`   |     Yes      |    Yes     |
| `Minimum angle difference (rad)`   | Minimum voltage-angle difference across the branch (in radians).                                                                                                                                                                           | `-inf`   |      No      |    Yes     |
| `Maximum angle difference (rad)`   | Maximum voltage-angle difference across the branch (in radians).                                                                                                                                                                           | `+inf`   |      No      |    Yes     |
| `Flow limit penalty ($/MW)`        | Penalty for violating the flow limits of the transmission line (in $/MW). This is charged per time step. For example, if there is a thermal violation of 1 MW for three time steps, then three times this amount will be charged. Negative value implies flow limit constraints must always be satisfied (hard constraints). No overflow variables are created. | `5000.0` |     Yes      |    Yes     |
| `Investment cost ($)`              | For candidate lines, the cost to build each parallel circuit along this corridor. For existing lines, this should be zero.                                                                                                                 |  `0.0`   |      No      |     No     |
| `Maximum parallel circuits` | For candidate lines, the maximum number of parallel circuits that can be built along this corridor. Unused for existing lines.                                                                                                             |   `1`    |      No      |     No     |

## Example

```json
{
  "Branches": {
    "l1": {
      "Source bus": "b1",
      "Target bus": "b2",
      "Resistance (p.u.)": 0.00281,
      "Reactance (p.u.)": 0.0281,
      "Shunt susceptance (p.u.)": 0.00712,
      "Normal flow limit (MVA)": 400.0,
      "Emergency flow limit (MVA)": 500.0,
      "Flow limit penalty ($/MW)": 5000.0,
      "Investment cost ($)": 3000000.0,
      "Maximum parallel circuits": 2
    },
    "t1": {
      "Source bus": "b2",
      "Target bus": "b3",
      "Resistance (p.u.)": 0.0,
      "Reactance (p.u.)": 0.01335,
      "Tap ratio (p.u.)": 1.05,
      "Phase shift (rad)": 0.0,
      "Normal flow limit (MVA)": 300.0
    }
  }
}
```

## Shunt devices

This section describes shunt devices (fixed or switchable) connected to the
network. Shunt devices inject or absorb reactive power and are modeled as
constant-impedance elements.

| Key                    | Description                                                                  | Default  | Time series? | Uncertain? |
| :--------------------- | :--------------------------------------------------------------------------- | :------: | :----------: | :--------: |
| `Bus`                  | Identifier of the bus where the shunt device is connected.                   | Required |      No      |    Yes     |
| `Conductance (p.u.)`   | Shunt conductance (in per unit on system `Base MVA`).                        |  `0.0`   |      No      |    Yes     |
| `Susceptance (p.u.)`   | Shunt susceptance (in per unit on system `Base MVA`). Positive = capacitive. | Required |      No      |    Yes     |
| `Status`               | Whether the shunt device is active (boolean).                                |  `true`  |     Yes      |    Yes     |

## Example

```json
{
  "Shunt devices": {
    "sh1": {
      "Bus": "b3",
      "Susceptance (p.u.)": 0.19,
      "Status": true
    },
    "sh2": {
      "Bus": "b5",
      "Conductance (p.u.)": 0.0,
      "Susceptance (p.u.)": -0.10,
      "Status": [true, true, false, false]
    }
  }
}
```

## Interfaces

This section describes named groups of branches (corridors) whose
aggregate weighted flow is bounded. Each interface specifies a set of branches with
signed weight coefficients and upper/lower flow limits.

| Key                         | Description                                                                                                                                                                                                  | Default  | Time series? | Uncertain? |
| :-------------------------- | :----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | :------: | :----------: | :--------: |
| `Branches`                  | Dictionary mapping branch names to their signed weight coefficients. Positive weights indicate outbound flow; negative weights indicate inbound flow.                                                        |   `{}`   |      No      |    Yes     |
| `Net flow upper limit (MW)` | Upper bound on the aggregate weighted flow through the interface.                                                                                                                                            |  `+inf`  |     Yes      |    Yes     |
| `Net flow lower limit (MW)` | Lower bound on the aggregate weighted flow through the interface.                                                                                                                                            |  `-inf`  |     Yes      |    Yes     |
| `Flow limit penalty ($/MW)` | Penalty for violating the flow limits of the interface (in $/MW). This is charged per time step. For example, if there is a violation of 1 MW for three time steps, three times this amount will be charged. Negative value implies flow limit constraints must always be satisfied (hard constraints). No overflow variables are created. | `5000.0` |     Yes      |    Yes     |

## Example

```json
{
  "Interfaces": {
    "ifc1": {
      "Branches": { "l1": 1.0, "l2": 1.0 },
      "Net flow upper limit (MW)": 120,
      "Net flow lower limit (MW)": -120,
      "Flow limit penalty ($/MW)": 5000.0
    },
    "ifc2": {
      "Branches": { "l3": 1.0, "l7": -1.0 },
      "Net flow upper limit (MW)": [50, 60, 60, 60],
      "Net flow lower limit (MW)": -100,
      "Flow limit penalty ($/MW)": 5000.0
    }
  }
}
```

## Reserves

This section describes the hourly amount of reserves required. Reserves may be
`"Spinning"` (provided by online generators) or `"Non-spinning"` (provided by
offline generators with fast-start capability). A reserve product may declare a
`"Parent"` to form a cascading (nested) hierarchy, where contributions to a
child reserve also count toward satisfying its parent.

| Key                        | Description                                                                                                                                                             | Default  | Time series? | Uncertain? |
| :------------------------- | :---------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------- | :----------: | :--------: |
| `Type`                     | Type of reserve product. Must be `"Spinning"` or `"Non-spinning"`.                                                                                                      | Required |      No      |     No     |
| `Amount (MW)`              | Amount of reserves required.                                                                                                                                            | Required |     Yes      |    Yes     |
| `Shortfall penalty ($/MW)` | Penalty for shortage in meeting the reserve requirements (in $/MW). This is charged per time step. Negative value implies reserve constraints must always be satisfied. | `-1`     |     Yes      |    Yes     |
| `Parent`                   | Name of parent reserve for cascading requirements. Contributions to this reserve also count toward satisfying the parent.                                               | `null`   |      No      |     No     |

## Example

```json
{
  "Reserves": {
    "r1": {
      "Type": "Spinning",
      "Amount (MW)": 400,
      "Shortfall penalty ($/MW)": 50,
      "Parent": "r2"
    },
    "r2": {
      "Type": "Non-spinning",
      "Amount (MW)": 1500,
      "Shortfall penalty ($/MW)": 1500,
      "Parent": "r3"
    },
    "r3": {
      "Type": "Spinning",
      "Amount (MW)": 2000,
      "Shortfall penalty ($/MW)": 1000
    }
  }
}
```

## Contingencies

This section describes credible contingency scenarios in the optimization, such
as the loss of a transmission line.

| Key                   | Description                                                                                       | Default | Uncertain? |
| :-------------------- | :------------------------------------------------------------------------------------------------ | :-----: | :--------: |
| `Affected generators` | List of generators affected by this contingency. May be omitted if no generators are affected.    |  `[]`   |    Yes     |
| `Affected branches`      | List of branches affected by this contingency. May be omitted if no branches are affected. |  `[]`   |    Yes     |

## Example

```json
{
  "Contingencies": {
    "c1": {
      "Affected branches": ["l1", "l2", "l3"],
      "Affected generators": ["g1"]
    },
    "c2": {
      "Affected branches": ["l4"]
    }
  }
}
```

## Additional remarks

## Time series parameters

Many numerical properties in the JSON file can be specified either as a single
floating point number if they are time-independent, or as an array containing
exactly `T` elements, if they are time-dependent, where `T` is the number of
time steps in the planning horizon. For example, both formats below are valid
when `T=3`:

```json
{
  "Load (MW)": 800.0,
  "Load (MW)": [800.0, 850.0, 730.0]
}
```

The value `T` depends on both `Time horizon (h)` and `Time step (min)`, as the
table below illustrates.

| Time horizon (h) | Time step (min) |  T  |
| :--------------: | :-------------: | :-: |
|        24        |       60        | 24  |
|        24        |       15        | 96  |
|        24        |        5        | 288 |
|        36        |       60        | 36  |
|        36        |       15        | 144 |
|        36        |        5        | 432 |

## Current limitations

- Network topology must remain the same for all time periods.
- Only N-1 transmission line contingencies are supported.
- Time-varying minimum production amounts are not currently compatible with
  ramp/startup/shutdown limits.
- The set of generators must be the same in all scenarios.
- AC formulations are significantly more computationally expensive than DC
  formulations and may require longer solve times for large instances.

