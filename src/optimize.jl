# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

"""
    optimize!(model::UnitCommitmentModel)::Nothing

Solve the given unit commitment model. Unlike `JuMP.optimize!`, this uses more
advanced methods to accelerate the solution process and to enforce transmission
and N-1 security constraints.
"""
function optimize!(model::UnitCommitmentModel)::Nothing
    optimize!(model.inner)
    _store_solution!(model)
    for ext in model.inner[:instance].extensions
        _after_optimize!(model.inner, ext)
    end
    validate(model.inner[:instance], model.data[:solution]) ||
        error("Invalid solution found.")
    return
end
