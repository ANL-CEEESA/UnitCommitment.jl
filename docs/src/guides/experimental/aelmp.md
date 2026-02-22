# Approximate Extended LMPs (AELMP)

The `AELMP` extension computes Approximate Extended Locational Marginal Prices, an alternative to conventional LMPs that aims to minimize uplift payments. The implementation is based on **MISO Phase I** of the extended LMP pricing methodology.

## Overview

AELMP modifies the unit commitment instance in three ways before solving a linear programming relaxation:

1. **Zero minimum power** -- Sets the minimum power output of each generator to zero, adding a new cost segment that extends the production cost curve down to zero output.
2. **Average startup costs** -- Distributes each generator's startup cost evenly across its production offer blocks (per MW of capacity).
3. **Relax integrality** -- Relaxes all binary and integer variables, solving the resulting LP to extract dual prices.

The resulting LMPs better reflect the marginal cost of serving load, including commitment-related costs, which can reduce out-of-market uplift payments compared to conventional LMPs.

## Constructor

```julia
UnitCommitment.AELMP(
    optimizer = HiGHS.Optimizer,
    allow_offline_participation = true,
    consider_startup_costs = true,
)
```

**Parameters:**

| Parameter | Type | Default | Description |
|---|---|---|---|
| `optimizer` | any JuMP optimizer | *(required)* | Optimizer used to solve the LP relaxation |
| `allow_offline_participation` | `Bool` | `true` | If `true`, all generators participate in pricing regardless of commitment status. If `false`, generators that are never committed in the solved UC model are excluded. |
| `consider_startup_costs` | `Bool` | `true` | If `true`, startup costs are averaged over each unit's production capacity and added to offer block costs. If `false`, startup costs are kept as-is. |

## Usage

`AELMP` occupies the `:lmp` extension slot, so it replaces `ConventionalLMP` when both are present. Pass it in the `extensions` list when reading an instance:

```julia
using UnitCommitment
using HiGHS

instance = UnitCommitment.read(
    "case.json",
    extensions = [
        UnitCommitment.AELMP(
            optimizer = HiGHS.Optimizer,
            allow_offline_participation = false,
            consider_startup_costs = true,
        ),
    ],
)

model = UnitCommitment.build_model(instance, optimizer = HiGHS.Optimizer)

UnitCommitment.optimize!(model)
```

When `allow_offline_participation = false`, the original UC model must be solved first (which `optimize!` handles automatically). An asset is considered offline if it is never committed throughout all time periods.

## Solution output

After optimization, the solution dictionary contains the same LMP keys as `ConventionalLMP`:

| Key | Description |
|---|---|
| `"LMP: Total ($/MWh)"` | Total locational marginal price per bus and time period |
| `"LMP: Energy ($/MWh)"` | Energy component of the LMP |
| `"LMP: Congestion ($/MWh)"` | Congestion component of the LMP |

Access them as follows:

```julia
solution = UnitCommitment.solution(model)
lmp = solution["s1"]["LMP: Total (\$/MWh)"]
lmp["b1"][1]  # LMP at bus "b1", time period 1
```

## Requirements and limitations

The AELMP implementation has several requirements that are validated at runtime:

- **Fast-start units only** -- All generators must have `min_uptime = 1` and `min_downtime = 1`.
- **Initial conditions** -- All generators must have `initial_power = 0` and `initial_status < 0` (i.e., initially offline).
- **No time-varying startup costs** -- Each generator may have at most one startup category.
- **Single scenario only** -- The instance must contain exactly one scenario.
