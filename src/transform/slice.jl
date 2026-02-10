# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

"""
    slice(instance, range)

Creates a new instance, with only a subset of the time periods.
This function does not modify the provided instance. The initial
conditions are also not modified.

Example
-------

```julia
# Build a 2-hour UC instance
instance = UnitCommitment.read_benchmark("matpower/case118/2017-02-01")
modified = UnitCommitment.slice(instance, 1:2)
```
"""
function slice(
    instance::UnitCommitmentInstance,
    range::UnitRange{Int},
)::UnitCommitmentInstance
    modified = deepcopy(instance)
    modified.time = length(range)
    for sc in modified.scenarios
        sc[:power_balance_penalty] = sc[:power_balance_penalty][range]
        for b in sc[:bus]
            b.load = b.load[range]
        end
        for ext in modified.extensions
            slice!(sc, range, ext)
        end
    end
    return modified
end

export slice
