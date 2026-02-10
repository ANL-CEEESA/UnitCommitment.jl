# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using JuMP
using MathOptInterface
using DataStructures
import JuMP: value, fix, set_name

"""
    build_model(; instance, optimizer=nothing, variable_names=false)::UnitCommitmentModel

Build an optimization model for the given unit commitment instance. Each
registered extension contributes variables, constraints, and objective terms
via its `build_model` method. After all extensions have been processed, bus-related
constraints are added and the objective is finalized.

# Arguments
- `instance::UnitCommitmentInstance`: the instance to formulate.
- `optimizer`: JuMP-compatible optimizer (e.g. `HiGHS.Optimizer`).
- `variable_names::Bool`: if `true`, assign human-readable names to all
  variables and constraints. Useful for debugging.

# Example

```julia
instance = UnitCommitment.read("case118.json.gz")
model = UnitCommitment.build_model(instance = instance, optimizer = HiGHS.Optimizer)
```
"""
function build_model(;
    instance::UnitCommitmentInstance,
    optimizer = nothing,
    variable_names::Bool = false,
)::UnitCommitmentModel
    model = Model()
    model.ext[:ucjl] = Dict()
    model[:obj] = AffExpr()
    model[:net_injection] = OrderedDict(
        (sc.name, b.name, t) => AffExpr(-b.load[t]) for
        sc in instance.scenarios for b in sc[:bus] for t in 1:instance.time
    )
    model[:instance] = instance
    for ext in instance.extensions
        build_model(model, instance, ext)
    end
    _add_buses!(model, instance)
    @objective(model, Min, model[:obj])
    if variable_names
        _set_names!(model)
    end
    if optimizer !== nothing
        set_optimizer(model, optimizer)
    end
    return UnitCommitmentModel(model)
end
