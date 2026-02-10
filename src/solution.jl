# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

"""
	solution(model::UnitCommitmentModel)::OrderedDict

Extracts the optimal solution from the UC.jl model. The model must be solved beforehand.

# Example

```julia
UnitCommitment.optimize!(model)
solution = UnitCommitment.solution(model)
```
"""
function solution(model::UnitCommitmentModel)::OrderedDict
    instance = model.inner[:instance]
    sol = model.inner.ext[:ucjl][:solution]

    if length(instance.scenarios) == 1
        sol = first(values(sol))
    end

    return sol
end

function _store_solution!(model::UnitCommitmentModel)::Nothing
    instance, T = model.inner[:instance], model.inner[:instance].time
    sol = OrderedDict()

    for sc in instance.scenarios
        sol[sc.name] = OrderedDict()
        _store_bus_solution!(sol[sc.name], model.inner, sc, T)
    end

    for ext in instance.extensions
        store_solution(sol, model.inner, ext)
    end

    model.inner.ext[:ucjl][:solution] = sol
    return
end
