# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using Printf

function validate(
    instance::UnitCommitmentInstance,
    solution::AbstractDict,
    ext::PhaseAngleTransmissionExt;
    tol = 0.01,
)::Int
    err_count = 0
    for sc in instance.scenarios
        branches = sc[:branches]

        flow_sol = solution[sc.name]["Branch: Base flow (MW)"]
        overflow_sol = solution[sc.name]["Branch: Base overflow (MW)"]

        for l in branches, t in 1:instance.time
            flow = flow_sol[l.name][t]
            overflow = overflow_sol[l.name][t]
            limit = l.normal_flow_limit[t]

            # Flow limit: |flow| <= limit + overflow
            if abs(flow) > limit + overflow + tol
                @error @sprintf(
                    "Line %s flow exceeds limit at time %d (|%.4f| > %.4f)",
                    l.name,
                    t,
                    flow,
                    limit + overflow,
                )
                err_count += 1
            end

            # Overflow consistency: overflow >= 0
            if overflow < -tol
                @error @sprintf(
                    "Line %s overflow is negative at time %d (%.4f)",
                    l.name,
                    t,
                    overflow,
                )
                err_count += 1
            end
        end
    end
    return err_count
end
