# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using Printf

function validate(
    instance::UnitCommitmentInstance,
    solution::AbstractDict,
    ext::DCTransmissionExt;
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

            # Base flow limit: |flow| <= limit + overflow
            if abs(flow) > limit + overflow + tol
                @error @sprintf(
                    "Line %s base flow exceeds limit at time %d (|%.4f| > %.4f)",
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

        # Contingency flow limits (when present in solution)
        cont_flow_sol =
            get(solution[sc.name], "Branch: Contingency flow (MW)", nothing)
        cont_overflow_sol =
            get(solution[sc.name], "Branch: Contingency overflow (MW)", nothing)

        if cont_flow_sol !== nothing && cont_overflow_sol !== nothing
            contingencies = sc[:contingencies]
            for cont in contingencies, l in branches, t in 1:instance.time
                cont_flow = cont_flow_sol[cont.name][l.name][t]
                cont_overflow = cont_overflow_sol[cont.name][l.name][t]
                limit = l.emergency_flow_limit[t]

                if abs(cont_flow) > limit + cont_overflow + tol
                    @error @sprintf(
                        "Line %s contingency %s flow exceeds emergency limit at time %d (|%.4f| > %.4f)",
                        l.name,
                        cont.name,
                        t,
                        cont_flow,
                        limit + cont_overflow,
                    )
                    err_count += 1
                end

                if cont_overflow < -tol
                    @error @sprintf(
                        "Line %s contingency %s overflow is negative at time %d (%.4f)",
                        l.name,
                        cont.name,
                        t,
                        cont_overflow,
                    )
                    err_count += 1
                end
            end
        end
    end
    return err_count
end
