# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using JuMP

function _read!(json::AbstractDict, sc::UnitCommitmentScenario, ext::UnitCommitmentExtension)
    # nop
end

function _build!(
    instance::UnitCommitmentInstance,
    ext::UnitCommitmentExtension,
)::Nothing
    # nop
end

function _before_optimize!(
    model::JuMP.Model,
    ext::UnitCommitmentExtension,
)::Nothing
    # nop
end

function _after_optimize!(
    model::JuMP.Model,
    ext::UnitCommitmentExtension,
)::Nothing
end

function _solution!(
    sol::AbstractDict,
    model::JuMP.Model,
    ext::UnitCommitmentExtension,
)::Nothing
    # nop
end
