# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

module AELMP

import ..PricingMethod

"""
    mutable struct Method
        allow_offline_participation::Bool,
        consider_startup_costs::Bool
    end

------

- `allow_offline_participation`:
    defaults to true. 
    If true, offline assets are allowed to participate in pricing.
- `consider_startup_costs`: 
    defaults to true. 
    If true, the start-up costs are averaged over each unit production; otherwise the production costs stay the same.

"""

mutable struct Method <: PricingMethod 
    allow_offline_participation::Bool
    consider_startup_costs::Bool

    function Method(;
        allow_offline_participation::Bool = true,
        consider_startup_costs::Bool = true
    )
        return new(
            allow_offline_participation,
            consider_startup_costs
        )
    end
end

end