# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using Printf

bin(x) = [xi > 0.5 for xi in x]

"""
    validate(instance, solution)::Bool

Verifies that the given solution is feasible for the problem. If feasible,
silently returns true. In infeasible, returns false and prints the validation
errors to the screen.

This function is implemented independently from the optimization models and
therefore can be used to verify that the model is indeed producing valid solutions.
It can also be used to verify the solutions produced by other optimization packages.
"""
function validate(
    instance::UnitCommitmentInstance,
    solution::Union{Dict,OrderedDict},
)::Bool
    if "Reserve: Provided (MW)" ∈ keys(solution)
        solution = Dict("s1" => solution)
    end
    err_count = 0
    for ext in instance.extensions
        err_count += validate(instance, solution, ext)
    end
    if err_count > 0
        @error "Found $err_count validation errors"
        return false
    end
    return true
end
