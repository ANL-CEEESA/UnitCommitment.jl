Data Format
===========

Input Data Format
-----------------

An instance of the stochastic security-constrained unit commitment (SCUC) problem is composed multiple scenarios. Each scenario should be described in an individual JSON file containing the main section belows. For deterministic instances, a single scenario file, following the same format below, may also be provided. Fields that are allowed to differ among scenarios are marked as "uncertain". Fields that are allowed to be time-dependent are marked as "time series".

* [Parameters](#Parameters)
* [Buses](#Buses)
* [Generators](#Generators)
* [Storage units](#Storage-units)
* [Price-sensitive loads](#Price-sensitive-loads)
* [Transmission lines](#Transmission-lines)
* [Reserves](#Reserves)
* [Contingencies](#Contingencies)

Each section is described in detail below. See [case118/2017-01-01.json.gz](https://axavier.org/UnitCommitment.jl/0.3/instances/matpower/case118/2017-01-01.json.gz) for a complete example.

### Parameters

This section describes system-wide parameters, such as power balance penalty, and optimization parameters, such as the length of the planning horizon and the time.

| Key                            | Description                                       | Default  | Time series? | Uncertain?
| :----------------------------- | :------------------------------------------------ | :------: | :------------:| :----------:
| `Version` | Version of UnitCommitment.jl this file was written for. Required to ensure that the file remains readable in future versions of the package. If you are following this page to construct the file, this field should equal `0.4`. | Required | No | No
| `Time horizon (min)` or  `Time horizon (h)` | Length of the planning horizon (in minutes or hours). Either `Time horizon (min)` or `Time horizon (h)` is required, but not both.  | Required | No | No
| `Time step (min)` | Length of each time step (in minutes). Must be a divisor of 60 (e.g. 60, 30, 20, 15, etc). | `60` | No | No
| `Power balance penalty ($/MW)` | Penalty for system-wide shortage or surplus in production (in $/MW). This is charged per time step. For example, if there is a shortage of 1 MW for three time steps, three times this amount will be charged. | `1000.0` | No | Yes
| `Scenario name` | Name of the scenario. | `"s1"` | No | ---
| `Scenario weight` | Weight of the scenario. The scenario weight can be any positive real number, that is, it does not have to be between zero and one. The package normalizes the weights to ensure that the probability of all scenarios sum up to one. | 1.0 | No | ---


#### Example
```json
{
    "Parameters": {
        "Version": "0.3",
        "Time horizon (h)": 4,
        "Power balance penalty ($/MW)": 1000.0,
        "Scenario name": "s1",
        "Scenario weight": 0.5
    }
}
```

### Buses

This section describes the characteristics of each bus in the system. 

| Key                | Description                                                   | Default | Time series? | Uncertain?
| :----------------- | :------------------------------------------------------------ | ------- | :-----------: | :---:
| `Load (MW)`        | Fixed load connected to the bus (in MW).                      | Required | Yes | Yes


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

This section describes all generators in the system. Two types of units can be specified:

- **Thermal units:** Units that produce power by converting heat into electrical energy, such as coal and oil power plants. These units use a more complex model, with binary decision variables, and various constraints to enforce ramp rates and minimum up/down time.
- **Profiled units:** Simplified model for units that do not require the constraints mentioned above, only a maximum and minimum power output for each time period. Typically used for renewables and hydro.

#### Thermal Units

| Key                       | Description                                      | Default | Time series? | Uncertain?
| :------------------------ | :------------------------------------------------| ------- | :-----------: | :---:
| `Bus`                     | Identifier of the bus where this generator is located (string). | Required | No | Yes
| `Type`                     | Type of the generator (string). For thermal generators, this must be `Thermal`.  | Required | No | No
| `Production cost curve (MW)` and `Production cost curve ($)` | Parameters describing the piecewise-linear production costs. See below for more details. | Required | Yes | Yes
| `Startup costs ($)` and `Startup delays (h)` | Parameters describing how much it costs to start the generator after it has been shut down for a certain amount of time. If `Startup costs ($)` and `Startup delays (h)` are set to `[300.0, 400.0]` and `[1, 4]`, for example, and the generator is shut down at time `00:00` (h:min), then it costs \$300 to start up the generator at any time between `01:00` and `03:59`, and \$400 to start the generator at time `04:00` or any time after that.  The number of startup cost points is unlimited, and may be different for each generator. Startup delays must be strictly increasing and the first entry must equal `Minimum downtime (h)`. | `[0.0]` and `[1]` | No | Yes
| `Minimum uptime (h)`      | Minimum amount of time the generator must stay operational after starting up (in hours). For example, if the generator starts up at time `00:00` (h:min) and `Minimum uptime (h)` is set to 4, then the generator can only shut down at time `04:00`. | `1` | No | Yes
| `Minimum downtime (h)`    | Minimum amount of time the generator must stay offline after shutting down (in hours). For example, if the generator shuts down at time `00:00` (h:min) and `Minimum downtime (h)` is set to 4, then the generator can only start producing power again at time `04:00`. | `1` | No | Yes
| `Ramp up limit (MW)`      | Maximum increase in production from one time step to the next (in MW). For example, if the generator is producing 100 MW at time step 1 and if this parameter is set to 40 MW, then the generator will produce at most 140 MW at time step 2. | `+inf` | No | Yes
| `Ramp down limit (MW)`    | Maximum decrease in production from one time step to the next (in MW). For example, if the generator is producing 100 MW at time step 1 and this parameter is set to 40 MW, then the generator will produce at least 60 MW at time step 2. | `+inf` | No | Yes
| `Startup limit (MW)`   | Maximum amount of power a generator can produce immediately after starting up (in MW). For example, if `Startup limit (MW)` is set to 100 MW and the unit is off at time step 1, then it may produce at most 100 MW at time step 2.| `+inf` | No | Yes
| `Shutdown limit (MW)`     | Maximum amount of power a generator can produce immediately before shutting down (in MW). Specifically, the generator can only shut down at time step `t+1` if its production at time step `t` is below this limit.  | `+inf` | No | Yes
| `Initial status (h)`  | If set to a positive number, indicates the amount of time (in hours) the generator has been on at the beginning of the simulation, and if set to a negative number, the amount of time the generator has been off. For example, if `Initial status (h)` is `-2`, this means that the generator was off since `-02:00` (h:min). The simulation starts at time `00:00`. If `Initial status (h)` is `3`, this means that the generator was on since `-03:00`. A value of zero is not acceptable. | Required | No | No
| `Initial power (MW)`  | Amount of power the generator at time step `-1`, immediately before the planning horizon starts. | Required | No | No
| `Must run?`               | If `true`, the generator should be committed, even if that is not economical (Boolean). | `false` | Yes | Yes
| `Reserve eligibility` | List of reserve products this generator is eligibe to provide. By default, the generator is not eligible to provide any reserves. | `[]` | No | Yes
| `Commitment status` | List of commitment status over the time horizon. At time `t`, if `true`, the generator must be commited at that time period; if `false`, the generator must not be commited at that time period. If `null` at time `t`, the generator's commitment status is then decided by the model. By default, the status is a list of `null` values. | `null` | Yes | Yes

#### Profiled Units

| Key               | Description                                       | Default  | Time series? | Uncertain?
| :---------------- | :------------------------------------------------ | :------: | :------------: | :---:
| `Bus`             | Identifier of the bus where this generator is located (string). | Required | No | Yes
| `Type`            | Type of the generator (string). For profiled generators, this must be `Profiled`.  | Required | No | No
| `Cost ($/MW)`     | Cost incurred for serving each MW of power by this generator. | Required | Yes | Yes
| `Minimum power (MW)` | Minimum amount of power this generator may supply. | `0.0` | Yes | Yes
| `Maximum power (MW)` | Maximum amount of power this generator may supply. | Required | Yes | Yes

#### Production costs and limits

Production costs are represented as piecewise-linear curves. Figure 1 shows an example cost curve with three segments, where it costs \$1400, \$1600, \$2200 and \$2400 to generate, respectively, 100, 110, 130 and 135 MW of power. To model this generator, `Production cost curve (MW)` should be set to `[100, 110, 130, 135]`, and `Production cost curve ($)`  should be set to `[1400, 1600, 2200, 2400]`.
Note that this curve also specifies the production limits. Specifically, the first point identifies the minimum power output when the unit is operational, while the last point identifies the maximum power output.

```@raw html
<center>
    <img src="../assets/cost_curve.png" style="max-width: 500px"/>
    <div><b>Figure 1.</b> Piecewise-linear production cost curve.</div>
    <br/>
</center>
```

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
            "Reserve eligibility": ["r1"]
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
            "Cost ($/MW)": 100.0
        }
    }
}
```

### Storage units

This section describes energy storage units in the system which charge and discharge power. The storage units consume power while charging, and generate power while discharging. 

| Key               | Description                                       | Default  | Time series? | Uncertain?
| :---------------- | :------------------------------------------------ | :------: | :------------: | :----: 
| `Bus`             | Bus where the storage unit is located. Multiple storage units may be placed at the same bus. | Required | No | Yes
| `Minimum level (MWh)`  | Minimum of energy level this storage unit may contain. | `0.0` | Yes | Yes
| `Maximum level (MWh)`  | Maximum of energy level this storage unit may contain. | Required | Yes | Yes
| `Allow simultaneous charging and discharging`  | If `false`, the storage unit is not allowed to charge and discharge at the same time (Boolean). | `true` | Yes | Yes
| `Charge cost ($/MW)`  | Cost incurred for charging each MW of power into this storage unit. | Required | Yes | Yes
| `Discharge cost ($/MW)`  | Cost incurred for discharging each MW of power from this storage unit. | Required | Yes | Yes
| `Charge efficiency`  | Efficiency rate to charge power into this storage unit. This value must be greater than or equal to `0.0`, and less than or equal to `1.0`. | `1.0` | Yes | Yes
| `Discharge efficiency`  | Efficiency rate to discharge power from this storage unit. This value must be greater than or equal to `0.0`, and less than or equal to `1.0`. | `1.0` | Yes | Yes
| `Loss factor`  | The energy dissipation rate of this storage unit. This value must be greater than or equal to `0.0`, and less than or equal to `1.0`. | `0.0` | Yes | Yes
| `Minimum charge rate (MW)`  | Minimum amount of power rate this storage unit may charge. | `0.0` | Yes | Yes
| `Maximum charge rate (MW)`  | Maximum amount of power rate this storage unit may charge. | Required | Yes | Yes
| `Minimum discharge rate (MW)`  | Minimum amount of power rate this storage unit may discharge. | `0.0` | Yes | Yes
| `Maximum discharge rate (MW)`  | Maximum amount of power rate this storage unit may discharge. | Required | Yes | Yes
| `Initial level (MWh)`  | Amount of energy this storage unit at time step `-1`, immediately before the planning horizon starts. | `0.0` | No | Yes
| `Last period minimum level (MWh)`  | Minimum of energy level this storage unit may contain in the last time step. By default, this value is the same as the last value of `Minimum level (MWh)`. | `Minimum level (MWh)` | No | Yes
| `Last period maximum level (MWh)`  | Maximum of energy level this storage unit may contain in the last time step. By default, this value is the same as the last value of `Maximum level (MWh)`. | `Maximum level (MWh)` | No | Yes

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
            "Maximum discharge rate (MW)": 8.0
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
            "Last period maximum level (MWh)": 85.0
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

This section describes components in the system which may increase or reduce their energy consumption according to the energy prices. Fixed loads (as described in the `buses` section) are always served, regardless of the price, unless there is significant congestion in the system or insufficient production capacity. Price-sensitive loads, on the other hand, are only served if it is economical to do so. 

| Key               | Description                                       | Default  | Time series? | Uncertain?
| :---------------- | :------------------------------------------------ | :------: | :------------: | :----: 
| `Bus`             | Bus where the load is located. Multiple price-sensitive loads may be placed at the same bus. | Required | No | Yes
| `Revenue ($/MW)`  | Revenue obtained for serving each MW of power to this load. | Required | Yes | Yes
| `Demand (MW)`     | Maximum amount of power required by this load. Any amount lower than this may be served. | Required | Yes | Yes


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

This section describes the characteristics of transmission system, such as its topology and the susceptance of each transmission line.

| Key                    | Description                                      | Default | Time series? | Uncertain?
| :--------------------- | :----------------------------------------------- | ------- | :------------: | :---:
| `Source bus`           | Identifier of the bus where the transmission line originates. | Required | No | Yes
| `Target bus`           | Identifier of the bus where the transmission line reaches. | Required | No | Yes
| `Susceptance (S)`      | Susceptance of the transmission line (in siemens). | Required | No | Yes
| `Normal flow limit (MW)` | Maximum amount of power (in MW) allowed to flow through the line when the system is in its regular, fully-operational state. | `+inf` | Yes | Yes
| `Emergency flow limit (MW)` | Maximum amount of power (in MW) allowed to flow through the line when the system is in degraded state (for example, after the failure of another transmission line). | `+inf` | Y | Yes
| `Flow limit penalty ($/MW)` | Penalty for violating the flow limits of the transmission line (in $/MW). This is charged per time step. For example, if there is a thermal violation of 1 MW for three time steps, then three times this amount will be charged. | `5000.0` | Yes | Yes

#### Example

```json
{
    "Transmission lines": {
        "l1": {
            "Source bus": "b1",
            "Target bus": "b2",
            "Susceptance (S)": 29.49686,
            "Normal flow limit (MW)": 15000.0,
            "Emergency flow limit (MW)": 20000.0,
            "Flow limit penalty ($/MW)": 5000.0
        }
    }
}
```


### Reserves

This section describes the hourly amount of reserves required.


| Key                   | Description                                        | Default   | Time series? | Uncertain?
| :-------------------- | :------------------------------------------------- | --------- | :----: | :---:
| `Type` | Type of reserve product. Must be either "spinning" or "flexiramp". | Required | No | No
| `Amount (MW)` | Amount of reserves required. | Required | Yes | Yes
| `Shortfall penalty ($/MW)` | Penalty for shortage in meeting the reserve requirements (in $/MW). This is charged per time step. Negative value implies reserve constraints must always be satisfied. | `-1` | Yes | Yes

#### Example 1

```json
{
    "Reserves": {
        "r1": {
            "Type": "spinning",
            "Amount (MW)": [
                57.30552,
                53.88429,
                51.31838,
                50.46307
            ],
            "Shortfall penalty ($/MW)": 5.0
        },
        "r2": {
            "Type": "flexiramp",
            "Amount (MW)": [
                20.31042,
                23.65273,
                27.41784,
                25.34057
            ],
        }
    }
}
```

### Contingencies

This section describes credible contingency scenarios in the optimization, such as the loss of a transmission line or generator.

| Key                   | Description                                      | Default | Uncertain?
| :-------------------- | :----------------------------------------------- | :--------: | :---:
| `Affected generators` | List of generators affected by this contingency. May be omitted if no generators are affected. | `[]` | Yes
| `Affected lines`      | List of transmission lines affected by this contingency. May be omitted if no lines are affected. | `[]` | Yes

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

* Network topology must remain the same for all time periods.
* Only N-1 transmission contingencies are supported. Generator contingencies are not currently supported.
* Time-varying minimum production amounts are not currently compatible with ramp/startup/shutdown limits.
* Flexible ramping products can only be acquired under the `WanHob2016` formulation, which does not support spinning reserves. 
* The set of generators must be the same in all scenarios.
