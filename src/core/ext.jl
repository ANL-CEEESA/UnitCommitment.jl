# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using JuMP

# Default (no-op) implementations of the extension lifecycle hooks.
# Extensions override only the hooks they need by dispatching on their
# concrete `UnitCommitmentExtension` subtype.

"""
    _read!(json, sc, ext)

Parse extension-specific data from the JSON dictionary and store it in the
scenario (`sc.data`). Called once per scenario during instance reading.

- `json::AbstractDict` — raw JSON dictionary for this scenario.
- `sc::UnitCommitmentScenario` — scenario being populated.
- `ext::UnitCommitmentExtension` — extension instance.
"""
function _read!(
    json::AbstractDict,
    sc::UnitCommitmentScenario,
    ext::UnitCommitmentExtension,
)
    # nop
end

"""
    _build!(model, instance, ext)

Add extension-specific variables, constraints, and objective terms to the
optimization model. Extensions that contribute to bus net injection should
add their terms to `model[:net_injection]` here.

- `model::JuMP.Model` — optimization model being constructed.
- `instance::UnitCommitmentInstance` — problem instance.
- `ext::UnitCommitmentExtension` — extension instance.
"""
function _build!(
    model::JuMP.Model,
    instance::UnitCommitmentInstance,
    ext::UnitCommitmentExtension,
)::Nothing
    # nop
end

"""
    _before_optimize!(model, ext)

Perform any last-minute model modifications right before the solver is invoked.

- `model::JuMP.Model` — optimization model about to be solved.
- `ext::UnitCommitmentExtension` — extension instance.
"""
function _before_optimize!(
    model::JuMP.Model,
    ext::UnitCommitmentExtension,
)::Nothing
    # nop
end

"""
    _after_optimize!(model, ext)

Run post-solve logic (e.g. fixing variables, computing prices) immediately
after the solver returns.

- `model::JuMP.Model` — solved optimization model.
- `ext::UnitCommitmentExtension` — extension instance.
"""
function _after_optimize!(
    model::JuMP.Model,
    ext::UnitCommitmentExtension,
)::Nothing end

"""
    _solution!(sol, model, ext)

Extract extension-specific results from the solved model and write them into
the solution dictionary.

- `sol::AbstractDict` — solution dictionary, keyed by scenario name.
- `model::JuMP.Model` — solved optimization model.
- `ext::UnitCommitmentExtension` — extension instance.
"""
function _solution!(
    sol::AbstractDict,
    model::JuMP.Model,
    ext::UnitCommitmentExtension,
)::Nothing
    # nop
end

"""
    _validate!(instance, solution, ext; tol=0.01) -> Int

Check that the solution satisfies extension-specific feasibility requirements.
Returns the number of validation errors found.

- `instance::UnitCommitmentInstance` — problem instance.
- `solution::AbstractDict` — solution dictionary, keyed by scenario name.
- `ext::UnitCommitmentExtension` — extension instance.
- `tol` — numerical tolerance for feasibility checks (default `0.01`).
"""
function _validate!(
    instance::UnitCommitmentInstance,
    solution::AbstractDict,
    ext::UnitCommitmentExtension;
    tol = 0.01,
)::Int
    return 0
end

"""
    _slice!(sc, range, ext)

Truncate extension-specific time-series data in the scenario to the given
time range. Called when creating a sub-horizon instance.

- `sc::UnitCommitmentScenario` — scenario being sliced.
- `range::UnitRange{Int}` — time-step range to keep.
- `ext::UnitCommitmentExtension` — extension instance.
"""
function _slice!(
    sc::UnitCommitmentScenario,
    range::UnitRange{Int},
    ext::UnitCommitmentExtension,
)::Nothing
    # nop
end

"""
    _summarize(instance, ext, io)

Print a short summary fragment for this extension to `io`. Used by
`Base.show` for `UnitCommitmentInstance` to include extension-specific
information in the instance summary.

- `instance::UnitCommitmentInstance` — problem instance.
- `ext::UnitCommitmentExtension` — extension instance.
- `io::IO` — output stream.
"""
function _summarize(
    instance::UnitCommitmentInstance,
    ext::UnitCommitmentExtension,
    io::IO,
)::Nothing
    # nop
end
