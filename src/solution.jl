# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

"""
	solution(model::UnitCommitmentModel)::OrderedDict

Extracts the optimal solution from the UC.jl model. The model must be solved beforehand.

# Example

```julia
model = build_model(instance)
optimize!(model)
solution = solution(model)
```
"""
function solution(model::UnitCommitmentModel)::OrderedDict
    haskey(model.data, :solution) ||
        error("No solution available. Call optimize!(model) first.")
    sol = model.data[:solution]
    return length(sol) == 1 ? first(values(sol)) : sol
end

function _store_solution!(model::UnitCommitmentModel)::Nothing
    instance = model.instance
    sol = OrderedDict(sc.name => OrderedDict() for sc in instance.scenarios)
    for sc in instance.scenarios
        _store_bus_solution!(sol[sc.name], model.inner, sc, instance.time)
    end
    for ext in instance.extensions
        store_solution(sol, model, ext)
    end
    model.data[:solution] = sol
    return
end

export solution
