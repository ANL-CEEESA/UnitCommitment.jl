# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

abstract type PricingMethod end

struct ConventionalLMP <: PricingMethod end

"""
    struct AELMP <: PricingMethod 
        allow_offline_participation::Bool = true
        consider_startup_costs::Bool = true
    end

Approximate Extended LMPs.

Arguments
---------

- `allow_offline_participation`:
    If true, offline assets are allowed to participate in pricing.
- `consider_startup_costs`: 
    If true, the start-up costs are averaged over each unit production; otherwise the production costs stay the same.
"""
Base.@kwdef struct AELMP <: PricingMethod 
    allow_offline_participation::Bool = true
    consider_startup_costs::Bool = true
end