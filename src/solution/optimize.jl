# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

"""
    function optimize!(model::JuMP.Model)::Nothing

Solve the given unit commitment model. Unlike JuMP.optimize!, this uses more
advanced methods to accelerate the solution process and to enforce transmission
and N-1 security constraints.
"""
function optimize!(model::JuMP.Model)::Nothing
    return UnitCommitment.optimize!(
        model,
        _XaQiWaTh19(
            time_limit = 3600.0,
            gap_limit = 1e-4,
            two_phase_gap = true,
            max_violations_per_line = 1,
            max_violations_per_period = 5,
        ),
    )
end
