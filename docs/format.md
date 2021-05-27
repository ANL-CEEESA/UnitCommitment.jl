```{sectnum}
---
start: 2
depth: 2
suffix: .
---
```


Data Format
===========


Input Data Format
-----------------

Instances are specified by JSON files containing the following main sections:

* Parameters
* Buses
* Generators
* Price-sensitive loads
* Transmission lines
* Reserves
* Contingencies

Each section is described in detail below. For a complete example, see [case14](https://github.com/ANL-CEEESA/UnitCommitment.jl/tree/dev/instances/matpower/case14).

### Parameters

This section describes system-wide parameters, such as power balance penalties,  optimization parameters, such as the length of the planning horizon and the time.

| Key                            | Description                                       | Default  | Time series?
| :----------------------------- | :------------------------------------------------ | :------: | :------------:
| `Time horizon (h)`                     | Length of the planning horizon (in hours). | Required | N
| `Time step (min)` | Length of each time step (in minutes). Must be a divisor of 60 (e.g. 60, 30, 20, 15, etc). | `60` | N
| `Power balance penalty ($/MW)` | Penalty for system-wide shortage or surplus in production (in $/MW). This is charged per time step. For example, if there is a shortage of 1 MW for three time steps, three times this amount will be charged. | `1000.0` | Y


#### Example
```json
{
    "Parameters": {
        "Time horizon (h)": 4,
        "Power balance penalty ($/MW)": 1000.0
    }
}
```

### Buses

This section describes the characteristics of each bus in the system. 

| Key                | Description                                                   | Default | Time series?
| :----------------- | :------------------------------------------------------------ | ------- | :-------------:
| `Load (MW)`        | Fixed load connected to the bus (in MW).                      | Required | Y


#### Example
```json
{
    "Buses": {
        "b1": {
            "Load (MW)": 0.0
        },
        "b2": {
            "Load (MW)": [
                26.01527,
                24.46212,
                23.29725,
                22.90897
            ]
        }
    }
}
```


### Generators

This section describes all generators in the system, including thermal units, renewable units and virtual units.

| Key                       | Description                                      | Default | Time series?
| :------------------------ | :------------------------------------------------| ------- | :-----------:
| `Bus`                     | Identifier of the bus where this generator is located (string). | Required | N
| `Production cost curve (MW)` and `Production cost curve ($)` | Parameters describing the piecewise-linear production costs. See below for more details. | Required | Y
| `Startup costs ($)` and `Startup delays (h)` | Parameters describing how much it costs to start the generator after it has been shut down for a certain amount of time. If `Startup costs ($)` and `Startup delays (h)` are set to `[300.0, 400.0]` and `[1, 4]`, for example, and the generator is shut down at time `00:00` (h:min), then it costs \$300 to start up the generator at any time between `01:00` and `03:59`, and \$400 to start the generator at time `04:00` or any time after that.  The number of startup cost points is unlimited, and may be different for each generator. Startup delays must be strictly increasing and the first entry must equal `Minimum downtime (h)`. | `[0.0]` and `[1]` | N
| `Minimum uptime (h)`      | Minimum amount of time the generator must stay operational after starting up (in hours). For example, if the generator starts up at time `00:00` (h:min) and `Minimum uptime (h)` is set to 4, then the generator can only shut down at time `04:00`. | `1` | N
| `Minimum downtime (h)`    | Minimum amount of time the generator must stay offline after shutting down (in hours). For example, if the generator shuts down at time `00:00` (h:min) and `Minimum downtime (h)` is set to 4, then the generator can only start producing power again at time `04:00`. | `1` | N
| `Ramp up limit (MW)`      | Maximum increase in production from one time step to the next (in MW). For example, if the generator is producing 100 MW at time step 1 and if this parameter is set to 40 MW, then the generator will produce at most 140 MW at time step 2. | `+inf` | N
| `Ramp down limit (MW)`    | Maximum decrease in production from one time step to the next (in MW). For example, if the generator is producing 100 MW at time step 1 and this parameter is set to 40 MW, then the generator will produce at least 60 MW at time step 2. | `+inf` | N
| `Startup limit (MW)`   | Maximum amount of power a generator can produce immediately after starting up (in MW). For example, if `Startup limit (MW)` is set to 100 MW and the unit is off at time step 1, then it may produce at most 100 MW at time step 2.| `+inf` | N
| `Shutdown limit (MW)`     | Maximum amount of power a generator can produce immediately before shutting down (in MW). Specifically, the generator can only shut down at time step `t+1` if its production at time step `t` is below this limit.  | `+inf` | N
| `Initial status (h)`  | If set to a positive number, indicates the amount of time (in hours) the generator has been on at the beginning of the simulation, and if set to a negative number, the amount of time the generator has been off. For example, if `Initial status (h)` is `-2`, this means that the generator was off since `-02:00` (h:min). The simulation starts at time `00:00`. If `Initial status (h)` is `3`, this means that the generator was on since `-03:00`. A value of zero is not acceptable. | Required | N
| `Initial power (MW)`  | Amount of power the generator at time step `-1`, immediately before the planning horizon starts. | Required | N
| `Must run?`               | If `true`, the generator should be committed, even if that is not economical (Boolean). | `false` | Y
| `Provides spinning reserves?`    | If `true`, this generator may provide spinning reserves (Boolean). | `true` | Y

#### Production costs and limits

Production costs are represented as piecewise-linear curves. Figure 1 shows an example cost curve with three segments, where it costs \$1400, \$1600, \$2200 and \$2400 to generate, respectively, 100, 110, 130 and 135 MW of power. To model this generator, `Production cost curve (MW)` should be set to `[100, 110, 130, 135]`, and `Production cost curve ($)`  should be set to `[1400, 1600, 2200, 2400]`.
Note that this curve also specifies the production limits. Specifically, the first point identifies the minimum power output when the unit is operational, while the last point identifies the maximum power output.

<center>
    <img src="../_static/cost_curve.png" style="max-width: 500px"/>
    <div><b>Figure 1.</b> Piecewise-linear production cost curve.</div>
    <br/>
</center>

#### Additional remarks:

* For time-dependent production limits or time-dependent production costs, the usage of nested arrays is allowed. For example,  if `Production cost curve (MW)` is set to `[5.0, [10.0, 12.0, 15.0, 20.0]]`, then the unit may generate at most 10, 12, 15 and 20 MW of power during time steps 1, 2, 3 and 4, respectively. The minimum output for all time periods is fixed to at 5 MW.
* There is no limit to the number of piecewise-linear segments, and different generators may have a different number of segments.
* If `Production cost curve (MW)` and `Production cost curve ($)` both contain a single element, then the generator must produce exactly that amount of power when operational. To specify that the generator may produce any amount of power up to a certain limit `P`, the parameter `Production cost curve (MW)` should be set to `[0, P]`. 
* Production cost curves must be convex.

#### Example

```json
{
    "Generators": {
        "gen1": {
            "Bus": "b1",
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
            "Must run?": false,
            "Provides spinning reserves?": true,
        },
        "gen2": {
            "Bus": "b5",
            "Production cost curve (MW)": [0.0, [10.0, 8.0, 0.0, 3.0]],
            "Production cost curve ($)": [0.0, 0.0],
            "Provides spinning reserves?": true,
        }
    }
}
```

### Price-sensitive loads

This section describes components in the system which may increase or reduce their energy consumption according to the energy prices. Fixed loads (as described in the `buses` section) are always served, regardless of the price, unless there is significant congestion in the system or insufficient production capacity. Price-sensitive loads, on the other hand, are only served if it is economical to do so. 

| Key               | Description                                       | Default  | Time series?
| :---------------- | :------------------------------------------------ | :------: | :------------:
| `Bus`             | Bus where the load is located. Multiple price-sensitive loads may be placed at the same bus. | Required | N
| `Revenue ($/MW)`  | Revenue obtained for serving each MW of power to this load. | Required | Y
| `Demand (MW)`     | Maximum amount of power required by this load. Any amount lower than this may be served. | Required | Y


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

### Transmission Lines

This section describes the characteristics of transmission system, such as its topology and the susceptance of each transmission line.

| Key                    | Description                                      | Default | Time series?
| :--------------------- | :----------------------------------------------- | ------- | :------------:
| `Source bus`           | Identifier of the bus where the transmission line originates. | Required | N
| `Target bus`           | Identifier of the bus where the transmission line reaches. | Required | N
| `Reactance (ohms)`     | Reactance of the transmission line (in ohms). | Required | N
| `Susceptance (S)`      | Susceptance  of the transmission line (in siemens). | Required | N
| `Normal flow limit (MW)` | Maximum amount of power (in MW) allowed to flow through the line when the system is in its regular, fully-operational state. | `+inf` | Y
| `Emergency flow limit (MW)` | Maximum amount of power (in MW) allowed to flow through the line when the system is in degraded state (for example, after the failure of another transmission line). | `+inf` | Y
| `Flow limit penalty ($/MW)` | Penalty for violating the flow limits of the transmission line (in $/MW). This is charged per time step. For example, if there is a thermal violation of 1 MW for three time steps, then three times this amount will be charged. | `5000.0` | Y

#### Example

```json
{
    "Transmission lines": {
        "l1": {
            "Source bus": "b1",
            "Target bus": "b2",
            "Reactance (ohms)": 0.05917,
            "Susceptance (S)": 29.49686,
            "Normal flow limit (MW)": 15000.0,
            "Emergency flow limit (MW)": 20000.0,
            "Flow limit penalty ($/MW)": 5000.0
        }
    }
}
```


### Reserves

This section describes the hourly amount of operating reserves required.


| Key                   | Description                                        | Default   |  Time series?
| :-------------------- | :------------------------------------------------- | --------- |  :----:
| `Spinning (MW)`       | Minimum amount of system-wide spinning reserves (in MW). Only generators which are online may provide this reserve. | `0.0` | Y

#### Example

```json
{
    "Reserves": {
        "Spinning (MW)": [
            57.30552,
            53.88429,
            51.31838,
            50.46307
        ]
    }
}
```

### Contingencies

This section describes credible contingency scenarios in the optimization, such as the loss of a transmission line or generator.

| Key                   | Description                                      | Default
| :-------------------- | :----------------------------------------------- | ----------
| `Affected generators`      | List of generators affected by this contingency. May be omitted if no generators are affected. | `[]`
| `Affected lines`      | List of transmission lines affected by this contingency. May be omitted if no lines are affected. | `[]`

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
        },
    }
}
```

### Additional remarks

#### Time series parameters

Many numerical properties in the JSON file can be specified either as a single floating point number if they are time-independent, or as an array containing exactly `T` elements, if they are time-dependent, where `T` is the number of time steps in the planning horizon. For example, both formats below are valid when `T=3`:

```json
{
    "Load (MW)": 800.0,
    "Load (MW)": [800.0, 850.0, 730.0]
}
```

The value `T` depends on both `Time horizon (h)` and `Time step (min)`, as the table below illustrates.

Time horizon (h) | Time step (min) | T
:---------------:|:---------------:|:----:
24               | 60              | 24
24               | 15              | 96
24               | 5               | 288
36               | 60              | 36
36               | 15              | 144
36               | 5               | 432

Output Data Format
------------------

The output data format is also JSON-based, but it is not currently documented since we expect it to change significantly in a future version of the package.


Current limitations
-------------------

* All reserves are system-wide. Zonal reserves are not currently supported.
* Network topology remains the same for all time periods
* Only N-1 transmission contingencies are supported. Generator contingencies are not currently supported.
* Time-varying minimum production amounts are not currently compatible with ramp/startup/shutdown limits.


