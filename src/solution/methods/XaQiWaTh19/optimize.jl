# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

"""
    optimize!(model::JuMP.Model, method::_XaQiWaTh19)::Nothing

Solve the given unit commitment model, enforcing transmission and N-1
security constraints lazily, according to the algorithm described in:

    Xavier, A. S., Qiu, F., Wang, F., & Thimmapuram, P. R. (2019). Transmission
    constraint filtering in large-scale security-constrained unit commitment. 
    IEEE Transactions on Power Systems, 34(3), 2457-2460.
"""
function optimize!(model::JuMP.Model, method::_XaQiWaTh19)::Nothing
    function set_gap(gap)
        try
            JuMP.set_optimizer_attribute(model, "MIPGap", gap)
            @info @sprintf("MIP gap tolerance set to %f", gap)
        catch
            @warn "Could not change MIP gap tolerance"
        end
    end
    instance = model[:instance]
    initial_time = time()
    large_gap = false
    has_transmission = (length(model[:isf]) > 0)
    if has_transmission && method.two_phase_gap
        set_gap(1e-2)
        large_gap = true
    else
        set_gap(method.gap_limit)
    end
    while true
        time_elapsed = time() - initial_time
        time_remaining = method.time_limit - time_elapsed
        if time_remaining < 0
            @info "Time limit exceeded"
            break
        end
        @info @sprintf(
            "Setting MILP time limit to %.2f seconds",
            time_remaining
        )
        JuMP.set_time_limit_sec(model, time_remaining)
        @info "Solving MILP..."
        JuMP.optimize!(model)
        has_transmission || break
        violations = _find_violations(
            model,
            max_per_line = method.max_violations_per_line,
            max_per_period = method.max_violations_per_period,
        )
        if isempty(violations)
            @info "No violations found"
            if large_gap
                large_gap = false
                set_gap(method.gap_limit)
            else
                break
            end
        else
            _enforce_transmission(model, violations)
        end
    end
    return
end