# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

function optimize!(model::JuMP.Model, method::XavQiuWanThi2019.Method)::Nothing
    if !occursin("Gurobi", JuMP.solver_name(model))
        method.two_phase_gap = false
    end
    function set_gap(gap)
        JuMP.set_optimizer_attribute(model, "MIPGap", gap)
        @info @sprintf("MIP gap tolerance set to %f", gap)
    end
    initial_time = time()
    large_gap = false
    has_transmission = false
    for sc in model[:instance].scenarios
        if length(sc.isf) > 0
            has_transmission = true
        end
        if has_transmission && method.two_phase_gap
            set_gap(1e-2)
            large_gap = true
        end
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

        @info "Verifying transmission limits..."
        time_screening = @elapsed begin
            violations = []
            for sc in model[:instance].scenarios
                push!(
                    violations,
                    _find_violations(
                        model,
                        sc,
                        max_per_line = method.max_violations_per_line,
                        max_per_period = method.max_violations_per_period,
                    ),
                )
            end
        end
        @info @sprintf(
            "Verified transmission limits in %.2f seconds",
            time_screening
        )

        violations_found = false
        for v in violations
            if !isempty(v)
                violations_found = true
            end
        end

        if violations_found
            for (i, v) in enumerate(violations)
                _enforce_transmission(model, v, model[:instance].scenarios[i])
            end
        else
            @info "No violations found"
            if large_gap
                large_gap = false
                set_gap(method.gap_limit)
            else
                break
            end
        end
    end
    return
end
