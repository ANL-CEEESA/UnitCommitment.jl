# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

import ..SolutionMethod

"""
    struct MarketSettings
        inner_method::SolutionMethod = XavQiuWanThi2019.Method()
        extensions::Vector = []
    end

Market setting struct, typically used to map a day-ahead market to real-time markets.

Arguments
---------

- `inner_method`:
    method to solve each marketing problem.
- `extensions`:
    list of extensions to apply to each instance (e.g. `ConventionalLMP()`).
    Extensions are passed to `UnitCommitment.read` and handle additional
    computations such as LMP pricing automatically.
"""
Base.@kwdef struct MarketSettings
    inner_method::SolutionMethod = XavQiuWanThi2019.Method()
    extensions::Vector = []
end
