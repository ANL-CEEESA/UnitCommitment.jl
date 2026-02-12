# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using JuMP

# Default (no-op) implementations of the extension lifecycle hooks.
# Extensions override only the hooks they need by dispatching on their
# concrete `UnitCommitmentExtension` subtype.

"""
    read_json(json, sc, ext)

Parse extension-specific data from the JSON dictionary and store it in the
scenario (`sc.data`). Called once per scenario during instance reading.

- `json::AbstractDict` — raw JSON dictionary for this scenario.
- `sc::UnitCommitmentScenario` — scenario being populated.
- `ext::UnitCommitmentExtension` — extension instance.
"""
function read_json(
    json::AbstractDict,
    sc::UnitCommitmentScenario,
    ext::UnitCommitmentExtension,
)
    # nop
end

"""
    build_model(model, instance, ext)

Add extension-specific variables, constraints, and objective terms to the
optimization model. Extensions that contribute to bus net injection should
add their terms to `model[:net_injection]` here.

- `model::JuMP.Model` — optimization model being constructed.
- `instance::UnitCommitmentInstance` — problem instance.
- `ext::UnitCommitmentExtension` — extension instance.
"""
function build_model(
    model::JuMP.Model,
    instance::UnitCommitmentInstance,
    ext::UnitCommitmentExtension,
)::Nothing
    # nop
end

function _after_optimize!(
    instance::UnitCommitmentInstance,
    model::UnitCommitmentModel,
    ext::UnitCommitmentExtension,
)::Nothing end

"""
    store_solution(sol, model, ext)

Extract extension-specific results from the solved model and write them into
the solution dictionary.

- `sol::AbstractDict` — solution dictionary, keyed by scenario name.
- `model::UnitCommitmentModel` — solved optimization model.
- `ext::UnitCommitmentExtension` — extension instance.
"""
function store_solution(
    sol::AbstractDict,
    model::UnitCommitmentModel,
    ext::UnitCommitmentExtension,
)::Nothing
    # nop
end

"""
    validate(instance, solution, ext; tol=0.01) -> Int

Check that the solution satisfies extension-specific feasibility requirements.
Returns the number of validation errors found.

- `instance::UnitCommitmentInstance` — problem instance.
- `solution::AbstractDict` — solution dictionary, keyed by scenario name.
- `ext::UnitCommitmentExtension` — extension instance.
- `tol` — numerical tolerance for feasibility checks (default `0.01`).
"""
function validate(
    instance::UnitCommitmentInstance,
    solution::AbstractDict,
    ext::UnitCommitmentExtension,
)::Int
    return 0
end

"""
    slice!(sc, range, ext)

Truncate extension-specific time-series data in the scenario to the given
time range. Called when creating a sub-horizon instance.

- `sc::UnitCommitmentScenario` — scenario being sliced.
- `range::UnitRange{Int}` — time-step range to keep.
- `ext::UnitCommitmentExtension` — extension instance.
"""
function slice!(
    sc::UnitCommitmentScenario,
    range::UnitRange{Int},
    ext::UnitCommitmentExtension,
)::Nothing
    # nop
end

"""
    repair!(sc, ext) -> Int

Fix extension-specific validation errors in the scenario, issuing a warning
for each error found. Returns the number of errors fixed.

- `sc::UnitCommitmentScenario` — scenario being repaired.
- `ext::UnitCommitmentExtension` — extension instance.
"""
function repair!(sc::UnitCommitmentScenario, ext::UnitCommitmentExtension)::Int
    return 0
end

"""
    summarize(instance, ext, io)

Print a short summary fragment for this extension to `io`. Used by
`Base.show` for `UnitCommitmentInstance` to include extension-specific
information in the instance summary.

- `instance::UnitCommitmentInstance` — problem instance.
- `ext::UnitCommitmentExtension` — extension instance.
- `io::IO` — output stream.
"""
function summarize(
    instance::UnitCommitmentInstance,
    ext::UnitCommitmentExtension,
    io::IO,
)::Nothing
    # nop
end
