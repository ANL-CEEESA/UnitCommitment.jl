# JSON data format

## Input Format

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
- [Transmission lines](#Transmission-lines)
- [Shunt devices](#Shunt-devices)
- [Reserves](#Reserves)
- [Contingencies](#Contingencies)

Each section is described in detail below. See
[case118/2017-01-01.json.gz](https://axavier.org/UnitCommitment.jl/0.5/instances/matpower/case118/2017-01-01.json.gz)
for a complete example.

### Parameters

This section describes system-wide parameters, such as power balance penalty,
and optimization parameters, such as the length of the planning horizon and the
time.

| Key                                        | Description                                                                                                                                                                                                                          | Default  | Time series? | Uncertain? |
| :----------------------------------------- | :----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | :------: | :----------: | :--------: |
| `Version`                                  | Version of UnitCommitment.jl this file was written for. Required to ensure that the file remains readable in future versions of the package. If you are following this page to construct the file, this field should equal `0.5`.    | Required |      No      |     No     |
| `Base MVA`                                 | System-wide base apparent power (in MVA) used for per-unit conversion of impedance, admittance, and voltage quantities.                                                                                                              | Required |      No      |     No     |
| `Time horizon (min)` or `Time horizon (h)` | Length of the planning horizon (in minutes or hours). Either `Time horizon (min)` or `Time horizon (h)` is required, but not both.                                                                                                   | Required |      No      |     No     |
| `Time step (min)`                          | Length of each time step (in minutes). Must be a divisor of 60 (e.g. 60, 30, 20, 15, etc).                                                                                                                                           |   `60`   |      No      |     No     |
| `Power balance penalty ($/MW)`             | Penalty for system-wide shortage or surplus in production (in $/MW). This is charged per time step. For example, if there is a shortage of 1 MW for three time steps, three times this amount will be charged.                       | `1000.0` |      No      |    Yes     |
| `Scenario name`                            | Name of the scenario.                                                                                                                                                                                                                |  `"s1"`  |      No      |    ---     |
| `Scenario weight`                          | Weight of the scenario. The scenario weight can be any positive real number, that is, it does not have to be between zero and one. The package normalizes the weights to ensure that the probability of all scenarios sum up to one. |  `1.0`   |      No      |    ---     |
| `Investment cost weight`                   | Weighting factor applied to investment costs. For transmission expansion planning problems, this can be used to scale investment costs relative to operation costs (e.g., convert one-time investment costs to hourly).              |  `1.0`   |      No      |    ---     |

#### Example

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

### Buses

This section describes the characteristics of each bus in the system.

| Key                          | Description                                                                                                  | Default  | Time series? | Uncertain? |
| :--------------------------- | :----------------------------------------------------------------------------------------------------------- | :------: | :----------: | :--------: |
| `Load (MW)`                  | Fixed active load connected to the bus (in MW).                                                              | Required |     Yes      |    Yes     |
| `Load (MVAr)`                | Fixed reactive load connected to the bus (in MVAr).                                                          |  `0.0`   |     Yes      |    Yes     |
| `Minimum voltage (p.u.)`     | Lower bound on the voltage magnitude at this bus (in per unit).                                              |  `0.9`   |      No      |    Yes     |
| `Maximum voltage (p.u.)`     | Upper bound on the voltage magnitude at this bus (in per unit).                                              |  `1.1`   |      No      |    Yes     |
| `Voltage magnitude (p.u.)`   | Initial or operating-point voltage magnitude at this bus (in per unit).                                      |  `1.0`   |      No      |    Yes     |
| `Voltage angle (rad)`        | Initial or operating-point voltage angle at this bus (in radians).                                           |  `0.0`   |      No      |    Yes     |
| `Bus type`                   | Bus classification: `"PQ"` (load bus), `"PV"` (generator bus with voltage control), or `"Slack"` (reference). | `"PQ"`  |      No      |     No     |

#### Example

```json
{
  "Buses": {
    "b1": {
      "Load (MW)": 0.0,
      "Load (MVAr)": 0.0,
      "Bus type": "Slack",
      "Voltage magnitude (p.u.)": 1.0,
      "Voltage angle (rad)": 0.0
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

### Generators

This section describes all generators in the system. Two types of units can be
specified:

- **Thermal units:** Units that produce power by converting heat into electrical
  energy, such as coal and oil power plants. These units use a more complex
  model, with binary decision variables, and various constraints to enforce ramp
  rates and minimum up/down time.
- **Profiled units:** Simplified model for units that do not require the
  constraints mentioned above, only a maximum and minimum power output for each
  time period. Typically used for renewables and hydro.

#### Thermal Units

| Key                                                          | Description                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        | Default           | Time series? | Uncertain? |
| :----------------------------------------------------------- | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------- | :----------: | :--------: |
| `Bus`                                                        | Identifier of the bus where this generator is located (string).                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    | Required          |      No      |    Yes     |
| `Type`                                                       | Type of the generator (string). For thermal generators, this must be `Thermal`.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    | Required          |      No      |     No     |
| `Production cost curve (MW)` and `Production cost curve ($)` | Parameters describing the piecewise-linear production costs. See below for more details.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           | Required          |     Yes      |    Yes     |
| `Startup costs ($)` and `Startup delays (h)`                 | Parameters describing how much it costs to start the generator after it has been shut down for a certain amount of time. If `Startup costs ($)` and `Startup delays (h)` are set to `[300.0, 400.0]` and `[1, 4]`, for example, and the generator is shut down at time `00:00` (h:min), then it costs \$300 to start up the generator at any time between `01:00` and `03:59`, and \$400 to start the generator at time `04:00` or any time after that. The number of startup cost points is unlimited, and may be different for each generator. Startup delays must be strictly increasing and the first entry must equal `Minimum downtime (h)`. | `[0.0]` and `[1]` |      No      |    Yes     |
| `Minimum uptime (h)`                                         | Minimum amount of time the generator must stay operational after starting up (in hours). For example, if the generator starts up at time `00:00` (h:min) and `Minimum uptime (h)` is set to 4, then the generator can only shut down at time `04:00`.                                                                                                                                                                                                                                                                                                                                                                                              | `1`               |      No      |    Yes     |
| `Minimum downtime (h)`                                       | Minimum amount of time the generator must stay offline after shutting down (in hours). For example, if the generator shuts down at time `00:00` (h:min) and `Minimum downtime (h)` is set to 4, then the generator can only start producing power again at time `04:00`.                                                                                                                                                                                                                                                                                                                                                                           | `1`               |      No      |    Yes     |
| `Ramp up limit (MW)`                                         | Maximum increase in production from one time step to the next (in MW). For example, if the generator is producing 100 MW at time step 1 and if this parameter is set to 40 MW, then the generator will produce at most 140 MW at time step 2.                                                                                                                                                                                                                                                                                                                                                                                                      | `+inf`            |      No      |    Yes     |
| `Ramp down limit (MW)`                                       | Maximum decrease in production from one time step to the next (in MW). For example, if the generator is producing 100 MW at time step 1 and this parameter is set to 40 MW, then the generator will produce at least 60 MW at time step 2.                                                                                                                                                                                                                                                                                                                                                                                                         | `+inf`            |      No      |    Yes     |
| `Startup limit (MW)`                                         | Maximum amount of power a generator can produce immediately after starting up (in MW). For example, if `Startup limit (MW)` is set to 100 MW and the unit is off at time step 1, then it may produce at most 100 MW at time step 2.                                                                                                                                                                                                                                                                                                                                                                                                                | `+inf`            |      No      |    Yes     |
| `Shutdown limit (MW)`                                        | Maximum amount of power a generator can produce immediately before shutting down (in MW). Specifically, the generator can only shut down at time step `t+1` if its production at time step `t` is below this limit.                                                                                                                                                                                                                                                                                                                                                                                                                                | `+inf`            |      No      |    Yes     |
| `Initial status (h)`                                         | If set to a positive number, indicates the amount of time (in hours) the generator has been on at the beginning of the simulation, and if set to a negative number, the amount of time the generator has been off. For example, if `Initial status (h)` is `-2`, this means that the generator was off since `-02:00` (h:min). The simulation starts at time `00:00`. If `Initial status (h)` is `3`, this means that the generator was on since `-03:00`. A value of zero is not acceptable.                                                                                                                                                      | Required          |      No      |     No     |
| `Initial power (MW)`                                         | Amount of power the generator at time step `-1`, immediately before the planning horizon starts.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   | Required          |      No      |     No     |
| `Must run?`                                                  | If `true`, the generator should be committed, even if that is not economical (Boolean).                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            | `false`           |     Yes      |    Yes     |
| `Reserve eligibility`                                        | List of reserve products this generator is eligible to provide. By default, the generator is not eligible to provide any reserves.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 | `[]`              |      No      |    Yes     |
| `Commitment status`                                          | List of commitment status over the time horizon. At time `t`, if `true`, the generator must be committed at that time period; if `false`, the generator must not be committed at that time period. If `null` at time `t`, the generator's commitment status is then decided by the model. By default, the status is a list of `null` values.                                                                                                                                                                                                                                                                                                       | `null`            |     Yes      |    Yes     |
| `Investment cost ($)`                                        | Cost to build a candidate generation unit. Should be zero for existing units.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      | `0.0`             |      No      |     No     |
| `Reactive power min (MVAr)`                                  | Minimum reactive power output (in MVAr).                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           | `-inf`            |      No      |    Yes     |
| `Reactive power max (MVAr)`                                  | Maximum reactive power output (in MVAr).                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           | `+inf`            |      No      |    Yes     |
| `Voltage set-point (p.u.)`                                   | Target voltage magnitude at the generator bus (in per unit). Used when the generator participates in voltage regulation.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           | `1.0`             |      No      |    Yes     |

#### Profiled Units

| Key                   | Description                                                                       | Default  | Time series? | Uncertain? |
| :-------------------- | :-------------------------------------------------------------------------------- | :------: | :----------: | :--------: |
| `Bus`                 | Identifier of the bus where this generator is located (string).                   | Required |      No      |    Yes     |
| `Type`                | Type of the generator (string). For profiled generators, this must be `Profiled`. | Required |      No      |     No     |
| `Cost ($/MW)`         | Cost incurred for serving each MW of power by this generator.                     | Required |     Yes      |    Yes     |
| `Minimum power (MW)`  | Minimum amount of power this generator may supply.                                |  `0.0`   |     Yes      |    Yes     |
| `Maximum power (MW)`  | Maximum amount of power this generator may supply.                                | Required |     Yes      |    Yes     |
| `Investment cost ($)`       | Cost to build a candidate generation unit. Should be zero for existing units.     |  `0.0`.  |      No      |     No     |
| `Reactive power min (MVAr)` | Minimum reactive power output (in MVAr).                                          |  `0.0`   |      No      |    Yes     |
| `Reactive power max (MVAr)` | Maximum reactive power output (in MVAr).                                          |  `0.0`   |      No      |    Yes     |

#### Production costs and limits

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

#### Additional remarks:

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

#### Example

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
      "Minimum downtime (h)": 4,
      "Minimum uptime (h)": 4,
      "Initial status (h)": 12,
      "Initial power (MW)": 115,
      "Must run?": false,
      "Reserve eligibility": ["r1"],
      "Reactive power min (MVAr)": -50.0,
      "Reactive power max (MVAr)": 80.0,
      "Voltage set-point (p.u.)": 1.02
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
      "Reactive power min (MVAr)": 0.0,
      "Reactive power max (MVAr)": 0.0
    }
  }
}
```

### Storage units

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
| `Reactive power min (MVAr)`                   | Minimum reactive power output (in MVAr).                                                                                                                    |         `0.0`         |      No      |    Yes     |
| `Reactive power max (MVAr)`                   | Maximum reactive power output (in MVAr).                                                                                                                    |         `0.0`         |      No      |    Yes     |
| `Apparent power limit (MVA)`                  | Inverter or thermal apparent-power rating (in MVA).                                                                                                         |        `+inf`         |      No      |    Yes     |

#### Example

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
      "Reactive power min (MVAr)": -5.0,
      "Reactive power max (MVAr)": 5.0,
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

### Price-sensitive loads

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

#### Example

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

### Transmission lines

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
| `Transformer`                      | Whether this branch is a transformer (boolean). When `true`, the tap ratio and phase shift parameters are active.                                                                                                                          | `false`  |      No      |     No     |
| `Normal flow limit (MVA)`          | Maximum apparent power (in MVA) allowed to flow through the branch when the system is in its regular, fully-operational state. For candidate lines, this represents the limit per invested circuit.                                        | `+inf`   |     Yes      |    Yes     |
| `Emergency flow limit (MVA)`       | Maximum apparent power (in MVA) allowed to flow through the branch when the system is in degraded state (for example, after the failure of another transmission line). For candidate lines, this represents the limit per invested circuit. | `+inf`   |     Yes      |    Yes     |
| `Angle difference min (rad)`       | Minimum voltage-angle difference across the branch (in radians).                                                                                                                                                                           | `-inf`   |      No      |    Yes     |
| `Angle difference max (rad)`       | Maximum voltage-angle difference across the branch (in radians).                                                                                                                                                                           | `+inf`   |      No      |    Yes     |
| `Flow limit penalty ($/MW)`        | Penalty for violating the flow limits of the transmission line (in $/MW). This is charged per time step. For example, if there is a thermal violation of 1 MW for three time steps, then three times this amount will be charged.          | `5000.0` |     Yes      |    Yes     |
| `Investment cost ($)`              | For candidate lines, the cost to build each parallel circuit along this corridor. For existing lines, this should be zero.                                                                                                                 |  `0.0`   |      No      |     No     |
| `Max number of parallel circuits`  | For candidate lines, the maximum number of parallel circuits that can be built along this corridor. Unused for existing lines.                                                                                                             |   `1`    |      No      |     No     |

#### Example

```json
{
  "Transmission lines": {
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
      "Max number of parallel circuits": 2
    },
    "t1": {
      "Source bus": "b2",
      "Target bus": "b3",
      "Resistance (p.u.)": 0.0,
      "Reactance (p.u.)": 0.01335,
      "Transformer": true,
      "Tap ratio (p.u.)": 1.05,
      "Phase shift (rad)": 0.0,
      "Normal flow limit (MVA)": 300.0
    }
  }
}
```

### Shunt devices

This section describes shunt devices (fixed or switchable) connected to the
network. Shunt devices inject or absorb reactive power and are modeled as
constant-impedance elements.

| Key                    | Description                                                                  | Default  | Time series? | Uncertain? |
| :--------------------- | :--------------------------------------------------------------------------- | :------: | :----------: | :--------: |
| `Bus`                  | Identifier of the bus where the shunt device is connected.                   | Required |      No      |    Yes     |
| `Conductance (p.u.)`   | Shunt conductance (in per unit on system `Base MVA`).                        |  `0.0`   |      No      |    Yes     |
| `Susceptance (p.u.)`   | Shunt susceptance (in per unit on system `Base MVA`). Positive = capacitive. | Required |      No      |    Yes     |
| `Status`               | Whether the shunt device is active (boolean).                                |  `true`  |     Yes      |    Yes     |

#### Example

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

### Reserves

This section describes the hourly amount of reserves required.

| Key                        | Description                                                                                                                                                             | Default  | Time series? | Uncertain? |
| :------------------------- | :---------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------- | :----------: | :--------: |
| `Type`                     | Type of reserve product. Must be either "spinning" or "flexiramp".                                                                                                      | Required |      No      |     No     |
| `Amount (MW)`              | Amount of reserves required.                                                                                                                                            | Required |     Yes      |    Yes     |
| `Shortfall penalty ($/MW)` | Penalty for shortage in meeting the reserve requirements (in $/MW). This is charged per time step. Negative value implies reserve constraints must always be satisfied. | `-1`     |     Yes      |    Yes     |

#### Example 1

```json
{
  "Reserves": {
    "r1": {
      "Type": "spinning",
      "Amount (MW)": [57.30552, 53.88429, 51.31838, 50.46307],
      "Shortfall penalty ($/MW)": 5.0
    },
    "r2": {
      "Type": "flexiramp",
      "Amount (MW)": [20.31042, 23.65273, 27.41784, 25.34057]
    }
  }
}
```

### Contingencies

This section describes credible contingency scenarios in the optimization, such
as the loss of a transmission line or generator.

| Key                   | Description                                                                                       | Default | Uncertain? |
| :-------------------- | :------------------------------------------------------------------------------------------------ | :-----: | :--------: |
| `Affected generators` | List of generators affected by this contingency. May be omitted if no generators are affected.    |  `[]`   |    Yes     |
| `Affected lines`      | List of transmission lines affected by this contingency. May be omitted if no lines are affected. |  `[]`   |    Yes     |

#### Example

```json
{
  "Contingencies": {
    "c1": {
      "Affected lines": ["l1", "l2", "l3"],
      "Affected generators": ["g1"]
    },
    "c2": {
      "Affected lines": ["l4"]
    }
  }
}
```

### Additional remarks

#### Time series parameters

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

### Current limitations

- Network topology must remain the same for all time periods.
- Only N-1 transmission contingencies are supported. Generator contingencies are
  not currently supported.
- Time-varying minimum production amounts are not currently compatible with
  ramp/startup/shutdown limits.
- The set of generators must be the same in all scenarios.
- AC formulations are significantly more computationally expensive than DC
  formulations and may require longer solve times for large instances.

## Output Format

After solving a unit commitment problem, the solution is provided as a
structured data format containing time series data for all decision variables
and computed metrics, organized by component type.

### Structure

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

### Buses

| Key                                  | Description                                                                                        | Unit  |
| :----------------------------------- | :------------------------------------------------------------------------------------------------- | :---- |
| `Bus: Net injection (MW)`            | Net active power injection at each bus.                                                            | MW    |
| `Bus: Load curtail (MW)`             | Amount of active load curtailed at each bus due to insufficient capacity or congestion.            | MW    |
| `Bus: Reactive load curtail (MVAr)`  | Amount of reactive load curtailed at each bus. Only present when AC formulation is used.           | MVAr  |
| `Bus: Voltage magnitude (p.u.)`      | Voltage magnitude at each bus. Only present when AC formulation is used.                           | p.u.  |
| `Bus: Voltage angle (rad)`           | Voltage angle at each bus. Only present when AC formulation is used.                               | rad   |
| `Bus: Fixed load expense ($)`        | Expense for serving fixed load at each bus (load times LMP). Only available if LMPs are computed.  | $     |

#### Example

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

### Locational Marginal Prices

| Key                         | Description                                                                                                                                                     | Unit    |
| :-------------------------- | :-------------------------------------------------------------------------------------------------------------------------------------------------------------- | :------ |
| `LMP: Total ($/MWh)`        | Total locational marginal price at each bus. Only available if LMPs are computed.                                                                               | $/MWh   |
| `LMP: Energy ($/MWh)`       | Energy component of LMP at each bus (minimum LMP across all buses at each time period). Only available if LMPs are computed.                                    | $/MWh   |
| `LMP: Congestion ($/MWh)`   | Congestion component of LMP at each bus (total LMP minus energy component). Only available if LMPs are computed.                                                | $/MWh   |

When an AC formulation is used, LMPs reflect AC marginal pricing and may differ
from DC-based LMPs due to losses and reactive power constraints.

#### Example

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

### Thermal Generators

| Key                            | Description                                                                                                                                          | Unit   |
| :----------------------------- | :--------------------------------------------------------------------------------------------------------------------------------------------------- | :----- |
| `Thermal: Production (MW)`     | Total power output from each thermal generator (minimum power plus segment production).                                                              | MW     |
| `Thermal: Utilization (%)`     | Percentage of maximum capacity being utilized (actual production divided by maximum power).                                                          | %      |
| `Thermal: Production cost ($)` | Total production cost for each thermal generator (minimum power cost plus variable costs).                                                           | $      |
| `Thermal: Startup cost ($)`    | Startup cost incurred by each thermal generator at each time period.                                                                                 | $      |
| `Thermal: Is on`               | Commitment status (1 if generator is on, 0 if off).                                                                                                  | Binary |
| `Thermal: Switch on`           | Switch-on indicator (1 if generator starts up at this time step, 0 otherwise).                                                                       | Binary |
| `Thermal: Switch off`          | Switch-off indicator (1 if generator shuts down at this time step, 0 otherwise).                                                                     | Binary |
| `Thermal: Gross revenue ($)`   | Revenue obtained from selling power at LMP (production times LMP). Only available if LMPs are computed.                                              | $      |
| `Thermal: Net revenue ($)`     | Net revenue after subtracting production and startup costs from gross revenue. Only available if LMPs are computed.                                  | $      |
| `Thermal: Uplift payment ($)`  | Make-whole payment needed to cover negative net revenue (zero if net revenue is positive). Only available if LMPs are computed.                      | $      |
| `Thermal: Reactive power (MVAr)` | Reactive power output from each thermal generator. Only present when AC formulation is used.                                                       | MVAr   |
| `Thermal: Investment status`   | Investment status for candidate thermal units (1 if invested by this time step, 0 otherwise). Only included for units with positive investment cost. | Binary |

#### Example

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

### Transmission Lines

| Key                           | Description                                                                                                                                       | Unit    |
| :---------------------------- | :------------------------------------------------------------------------------------------------------------------------------------------------ | :------ |
| `Line: Flow (MW)`             | Pre-contingency active power flow through each transmission line.                                                                                 | MW      |
| `Line: Reactive flow (MVAr)`  | Reactive power flow through each transmission line. Only present when AC formulation is used.                                                    | MVAr    |
| `Line: Overflow (MW)`         | Amount of power flow exceeding the line's thermal limit.                                                                                          | MW      |
| `Line: Overflow penalty ($)`  | Penalty cost incurred for overflow violations on each line (overflow amount times flow penalty cost).                                             | $       |
| `Line: Utilization (%)`       | Percentage of line capacity being utilized (absolute flow divided by normal flow limit).                                                          | %       |
| `Line: Investment cost ($)`   | Incremental investment cost at each time period (cost of new circuits built at time t, not cumulative). Only included for lines with positive investment cost. | $       |
| `Line: Investment status`     | Number of parallel circuits invested along each candidate line corridor by this time step. Only included for lines with positive investment cost. | Integer |

#### Example

```json
{
  "Line: Flow (MW)": {
    "l1": [125.3, 130.8, 128.2, 135.5],
    "l2": [-85.7, -92.5, -91.3, -87.3]
  },
  "Line: Reactive flow (MVAr)": {
    "l1": [18.2, 19.5, 18.8, 20.1],
    "l2": [-12.3, -14.1, -13.5, -12.8]
  },
  "Line: Overflow (MW)": {
    "l1": [0.0, 0.0, 0.0, 0.0],
    "l2": [0.0, 2.5, 1.3, 0.0]
  },
  "Line: Overflow penalty ($)": {
    "l1": [0.0, 0.0, 0.0, 0.0],
    "l2": [0.0, 12500.0, 6500.0, 0.0]
  },
  "Line: Utilization (%)": {
    "l1": [83.53, 87.2, 85.47, 90.33],
    "l2": [95.22, 102.78, 101.44, 97.0]
  },
  "Line: Investment cost ($)": {
    "l3": [0.0, 3000000.0, 0.0, 3000000.0]
  },
  "Line: Investment status": {
    "l3": [0.0, 1.0, 1.0, 2.0]
  }
}
```

### Price-Sensitive Loads

| Key                                        | Description                                                                                          | Unit |
| :----------------------------------------- | :--------------------------------------------------------------------------------------------------- | :--- |
| `Price-sensitive load: Demand served (MW)` | Amount of price-sensitive load demand served at each bus.                                            | MW   |
| `Price-sensitive load: Expense ($)`        | Expense incurred for serving price-sensitive load (demand served times LMP). Only available if LMPs are computed. | $    |

#### Example

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

### Profiled Generators

| Key                             | Description                                                                                                                                           | Unit   |
| :------------------------------ | :---------------------------------------------------------------------------------------------------------------------------------------------------- | :----- |
| `Profiled: Production (MW)`     | Power output from each profiled generator (renewables, hydro, etc.).                                                                                  | MW     |
| `Profiled: Utilization (%)`     | Percentage of maximum capacity being utilized (actual production divided by maximum power).                                                           | %      |
| `Profiled: Production cost ($)` | Production cost for each profiled generator (output times cost).                                                                                      | $      |
| `Profiled: Gross revenue ($)`   | Revenue obtained from selling power at LMP (production times LMP). Only available if LMPs are computed.                                               | $      |
| `Profiled: Net revenue ($)`     | Net revenue after subtracting production costs from gross revenue. Only available if LMPs are computed.                                               | $      |
| `Profiled: Uplift payment ($)`  | Make-whole payment needed to cover negative net revenue (zero if net revenue is positive). Only available if LMPs are computed.                       | $      |
| `Profiled: Reactive power (MVAr)` | Reactive power output from each profiled generator. Only present when AC formulation is used.                                                       | MVAr   |
| `Profiled: Investment status`   | Investment status for candidate profiled units (1 if invested by this time step, 0 otherwise). Only included for units with positive investment cost. | Binary |

#### Example

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

### Storage Units

| Key                              | Description                                                                                                                                          | Unit   |
| :------------------------------- | :--------------------------------------------------------------------------------------------------------------------------------------------------- | :----- |
| `Storage: Level (MWh)`           | Energy level stored in each storage unit.                                                                                                            | MWh    |
| `Storage: Is charging`           | Charging indicator (1 if storage unit is charging, 0 otherwise).                                                                                     | Binary |
| `Storage: Charging rate (MW)`    | Power rate at which each storage unit is charging.                                                                                                   | MW     |
| `Storage: Charging cost ($)`     | Cost incurred for charging each storage unit (rate times cost).                                                                                      | $      |
| `Storage: Is discharging`        | Discharging indicator (1 if storage unit is discharging, 0 otherwise).                                                                               | Binary |
| `Storage: Discharging rate (MW)` | Power rate at which each storage unit is discharging.                                                                                                | MW     |
| `Storage: Discharging cost ($)`  | Cost incurred for discharging each storage unit (rate times cost).                                                                                   | $      |
| `Storage: Reactive power (MVAr)` | Reactive power output from each storage unit. Only present when AC formulation is used.                                                              | MVAr   |
| `Storage: Investment status`     | Investment status for candidate storage units (1 if invested by this time step, 0 otherwise). Only included for units with positive investment cost. | Binary |

#### Example

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

### Reserves

| Key                                      | Description                                                                                                                                                      | Unit |
| :--------------------------------------- | :--------------------------------------------------------------------------------------------------------------------------------------------------------------- | :--- |
| `Reserve: Spinning (MW)`                 | Amount of spinning reserve provided by each thermal generator for each spinning reserve product. Nested structure: `reserve_name -> generator_name -> [values]`. | MW   |
| `Reserve: Spinning shortfall (MW)`       | Amount of spinning reserve requirement not met for each reserve product.                                                                                         | MW   |
| `Reserve: Up-flexiramp (MW)`             | Amount of up-flexiramp reserve provided by each thermal generator for each flexiramp product. Nested structure: `reserve_name -> generator_name -> [values]`.    | MW   |
| `Reserve: Up-flexiramp shortfall (MW)`   | Amount of up-flexiramp reserve requirement not met for each flexiramp product.                                                                                   | MW   |
| `Reserve: Down-flexiramp (MW)`           | Amount of down-flexiramp reserve provided by each thermal generator for each flexiramp product. Nested structure: `reserve_name -> generator_name -> [values]`.  | MW   |
| `Reserve: Down-flexiramp shortfall (MW)` | Amount of down-flexiramp reserve requirement not met for each flexiramp product.                                                                                 | MW   |

#### Example

```json
{
  "Reserve: Spinning (MW)": {
    "r1": {
      "g1": [15.0, 18.5, 16.2, 17.8],
      "g2": [0.0, 5.5, 6.8, 7.2]
    }
  },
  "Reserve: Spinning shortfall (MW)": {
    "r1": [0.0, 0.0, 0.0, 0.0]
  },
  "Reserve: Up-flexiramp (MW)": {
    "r2": {
      "g1": [8.0, 9.5, 8.5, 9.0],
      "g2": [0.0, 3.5, 4.0, 3.8]
    }
  },
  "Reserve: Up-flexiramp shortfall (MW)": {
    "r2": [0.0, 0.0, 0.0, 0.0]
  },
  "Reserve: Down-flexiramp (MW)": {
    "r2": {
      "g1": [7.5, 8.0, 7.8, 8.2],
      "g2": [0.0, 3.0, 3.5, 3.3]
    }
  },
  "Reserve: Down-flexiramp shortfall (MW)": {
    "r2": [0.0, 0.0, 0.0, 0.0]
  }
}
```
### Notes

- Investment status variables show the cumulative investment decision (whether
  the unit/line is built by time `t`), not the incremental decision at time `t`.
- Reserve variables use a nested structure where the outer object is indexed by
  reserve product name, and the inner object is indexed by generator name.
- Components with zero investment cost do not appear in the investment status
  fields.
- Empty collections (e.g., no storage units in the instance) result in empty
  objects for that component type.
