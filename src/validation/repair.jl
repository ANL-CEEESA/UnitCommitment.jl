# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

"""
    repair!(instance)

Verifies that the given unit commitment instance is valid and automatically
fixes some validation errors if possible, issuing a warning for each error
found. If a validation error cannot be automatically fixed, issues an
exception.

Returns the number of validation errors found.
"""
function repair!(instance::UnitCommitmentInstance)::Int
    n_errors = 0
    for sc in instance.scenarios
        for ext in instance.extensions
            n_errors += repair!(sc, ext)
        end
    end
    return n_errors
end

export repair!
