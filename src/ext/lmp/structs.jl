# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

"""
    ConventionalLMP()

Calculates conventional locational marginal prices of the given unit commitment
instance. After the model is solved, binary variables are fixed to their optimal
values, integrality is relaxed, and dual values are extracted as LMPs.

Locational marginal prices for each bus and time period are stored in the
solution dictionary.

Examples
--------

```julia
using UnitCommitment
using HiGHS

# Read benchmark instance with ConventionalLMP extension
instance = UnitCommitment.read(
    "path/to/instance.json",
    extensions = [
        UnitCommitment.ConventionalLMP(),
    ],
)

# Build and solve the model
model = UnitCommitment.build_model(
    instance = instance,
    optimizer = optimizer_with_attributes(
        HiGHS.Optimizer,
        "log_to_console" => false,
    ),
)

UnitCommitment.optimize!(model)

# Access the LMPs from the solution
solution = UnitCommitment.solution(model)
lmp = solution["s1"]["LMP: Total (\$/MWh)"]
@show lmp["b1"][1]
```
"""
struct ConventionalLMP <: UnitCommitmentExtension end

"""
    AELMP(;
        allow_offline_participation::Bool = true,
        consider_startup_costs::Bool = true,
        optimizer,
    )

Calculates the approximate extended locational marginal prices of the given unit commitment instance.

The AELPM does the following three things:

    1. It sets the minimum power output of each generator to zero
    2. It averages the start-up cost over the offer blocks for each generator
    3. It relaxes all integrality constraints

Returns locational marginal prices for each bus and time period in the solution dictionary.

WARNING: This approximation method is not fully developed. The implementation is based on MISO Phase I only.

1. It only supports Fast Start resources. More specifically, the minimum up/down time has to be 1.
2. The method does NOT support time-varying start-up costs.
3. An asset is considered offline if it is never on throughout all time periods.
4. The method does NOT support multiple scenarios.

Arguments
---------

- `allow_offline_participation::Bool`:
    If false, generators that are never on throughout all time periods will be excluded from the approximation.
    A solved UC model is required when this is set to false.

- `consider_startup_costs::Bool`:
    If true, start-up costs are averaged over the offer blocks for each generator.

- `optimizer`:
    The optimizer for solving the LP relaxation problem.

Examples
--------

```julia
using UnitCommitment
using HiGHS

# Read benchmark instance with AELMP extension
instance = UnitCommitment.read(
    "path/to/instance.json",
    extensions = [
        UnitCommitment.AELMP(
            allow_offline_participation = false,
            consider_startup_costs = true,
            optimizer = optimizer_with_attributes(
                HiGHS.Optimizer,
                "log_to_console" => false,
            ),
        ),
    ],
)

# Build and solve the model
model = UnitCommitment.build_model(
    instance = instance,
    optimizer = optimizer_with_attributes(
        HiGHS.Optimizer,
        "log_to_console" => false,
    ),
)

UnitCommitment.optimize!(model)

# Access the AELMPs from the solution
solution = UnitCommitment.solution(model)
lmp = solution["LMP: Total (\$/MWh)"]
@show lmp["B1"][1]
```
"""
Base.@kwdef struct AELMP <: UnitCommitmentExtension
    allow_offline_participation::Bool = true
    consider_startup_costs::Bool = true
    optimizer::Any
end
