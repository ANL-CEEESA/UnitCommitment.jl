# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

import ..SolutionMethod
import ..PricingMethod
import ..Formulation

"""
    struct MarketSettings
        inner_method::SolutionMethod = XavQiuWanThi2019.Method()
        lmp_method::Union{PricingMethod, Nothing} = ConventionalLMP()
        formulation::Formulation = Formulation()
    end

Market setting struct, typically used to map a day-ahead market to real-time markets.

Arguments
---------

- `inner_method`: 
    method to solve each marketing problem.
- `lmp_method`:
    a PricingMethod method to calculate the locational marginal prices.
    If it is set to `nothing`, the LMPs will not be calculated.
- `formulation`:
    problem formulation.
"""
Base.@kwdef struct MarketSettings
    inner_method::SolutionMethod = XavQiuWanThi2019.Method()
    lmp_method::Union{PricingMethod,Nothing} = ConventionalLMP()
    formulation::Formulation = Formulation()
end
