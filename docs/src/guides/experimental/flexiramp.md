# Flexiramp Reserves

The `WanHob2016.FlexirampExt` extension adds flexiramp reserve constraints to the unit commitment model. The formulation is based on:

> B. Wang and B. F. Hobbs, "Real-Time Markets for Flexiramp: A Stochastic Unit Commitment-Based Analysis," *IEEE Transactions on Power Systems*, vol. 31, no. 2, pp. 846-860, March 2016, doi: 10.1109/TPWRS.2015.2411268.

## Usage

`FlexirampExt` includes its own ramping constraints (Eq. 23-25 from the paper), which cover ramp-up limits, shutdown ramp limits, and ramp-down limits. To avoid duplicate ramping constraints, use `ThermalExt(ramping = NoRamping())`:

```julia
using UnitCommitment
using HiGHS

instance = UnitCommitment.read(
    "case.json",
    extensions = [
        UnitCommitment.ThermalExt(ramping = UnitCommitment.NoRamping()),
        UnitCommitment.WanHob2016.FlexirampExt(),
    ],
)

model = UnitCommitment.build_model(instance, optimizer = HiGHS.Optimizer)

UnitCommitment.optimize!(model)
```

## JSON data format

Flexiramp reserves are specified in the `"Reserves"` section of the instance JSON file. Each reserve must have `"Type": "flexiramp"` and an `"Amount (MW)"` time series specifying the required flexiramp capacity at each time period. An optional `"Shortfall penalty ($/MW)"` sets the penalty cost for unmet requirements; if omitted or set to a negative value, shortfalls are disallowed.

Generators are linked to flexiramp reserves through their `"Reserve eligibility"` field, which lists the names of reserves the generator can participate in.

```json
{
    "Generators": {
        "g2": {
            "Bus": "b2",
            "Production cost curve (MW)": [0, 47, 94, 140],
            "Production cost curve ($)": [0, 2256.00, 4733.37, 7395.39],
            "Ramp up limit (MW)": 98.0,
            "Ramp down limit (MW)": 70.0,
            "Startup limit (MW)": 80.0,
            "Shutdown limit (MW)": 60.0,
            "Reserve eligibility": ["r1"]
        }
    },
    "Reserves": {
        "r1": {
            "Type": "flexiramp",
            "Amount (MW)": [20.0, 23.0, 27.0, 25.0],
            "Shortfall penalty ($/MW)": 5000.0
        }
    }
}
```

## Requirements

- **Constant minimum power** -- All generators participating in flexiramp reserves must have a constant `min_power` across all time periods. The formulation uses `min_power` values from adjacent time periods interchangeably, so time-varying minimum power is not supported. A runtime error is raised if this condition is violated.

## Decision variables

The extension introduces the following decision variables:

| Variable | Indexed by | Description |
|---|---|---|
| `mfg` | scenario, generator, time | Maximum feasible generation for each participating generator |
| `upflexiramp` | scenario, reserve, generator, time | Up-flexiramp provision (defined for `t = 1` to `T-1`) |
| `dwflexiramp` | scenario, reserve, generator, time | Down-flexiramp provision (defined for `t = 1` to `T-1`) |
| `upflexiramp_shortfall` | scenario, reserve, time | Up-flexiramp shortfall (defined for `t = 1` to `T-1`) |
| `dwflexiramp_shortfall` | scenario, reserve, time | Down-flexiramp shortfall (defined for `t = 1` to `T-1`) |

## Solution output

After optimization, the solution dictionary contains the following keys (nested under the scenario name):

| Key | Indexed by | Description |
|---|---|---|
| `"Flexiramp: Up (MW)"` | reserve, generator, time | Up-flexiramp provision per generator and reserve |
| `"Flexiramp: Down (MW)"` | reserve, generator, time | Down-flexiramp provision per generator and reserve |
| `"Flexiramp: MFG (MW)"` | generator, time | Maximum feasible generation per generator |
| `"Flexiramp: Up shortfall (MW)"` | reserve, time | Unmet up-flexiramp requirement per reserve |
| `"Flexiramp: Down shortfall (MW)"` | reserve, time | Unmet down-flexiramp requirement per reserve |

Access them as follows:

```julia
solution = UnitCommitment.solution(model)
up = solution["s1"]["Flexiramp: Up (MW)"]
up["r1"]["g2"]  # Up-flexiramp provision by generator "g2" for reserve "r1"
```

Note that up/down flexiramp and shortfall values are defined for time periods `1` to `T-1` (where `T` is the number of time periods), since the formulation concerns transitions between consecutive intervals.
