# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

function validate(
    instance::UnitCommitmentInstance,
    solution::AbstractDict,
    ::InterfaceLimitsExt;
    tol = 0.01,
)::Int
    err_count = 0

    for sc in instance.scenarios
        interfaces = sc[:interfaces]
        isempty(interfaces) && continue

        line_flow = solution[sc.name]["Line: Base Flow (MW)"]

        for ifc in interfaces
            reported_flow = solution[sc.name]["Interface: Flow (MW)"][ifc.name]

            for t in 1:instance.time
                # Recompute interface flow from individual line flows
                computed_flow = 0.0
                for line in ifc.lines
                    w = ifc.weight_by_line[line]
                    computed_flow += w * line_flow[line.name][t]
                end

                # Verify reported flow matches recomputed flow
                if abs(reported_flow[t] - computed_flow) > tol
                    @error @sprintf(
                        "%s %s t=%d: reported flow %.2f != computed flow %.2f",
                        sc.name,
                        ifc.name,
                        t,
                        reported_flow[t],
                        computed_flow,
                    )
                    err_count += 1
                end

                # Check upper bound
                if isfinite(ifc.net_flow_ub[t]) &&
                   computed_flow > ifc.net_flow_ub[t] + tol
                    @error @sprintf(
                        "%s %s t=%d: flow %.2f exceeds upper limit %.2f",
                        sc.name,
                        ifc.name,
                        t,
                        computed_flow,
                        ifc.net_flow_ub[t],
                    )
                    err_count += 1
                end

                # Check lower bound
                if isfinite(ifc.net_flow_lb[t]) &&
                   computed_flow < ifc.net_flow_lb[t] - tol
                    @error @sprintf(
                        "%s %s t=%d: flow %.2f below lower limit %.2f",
                        sc.name,
                        ifc.name,
                        t,
                        computed_flow,
                        ifc.net_flow_lb[t],
                    )
                    err_count += 1
                end
            end
        end
    end
    return err_count
end
