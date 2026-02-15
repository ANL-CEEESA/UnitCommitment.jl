# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using Printf

function validate(
    instance::UnitCommitmentInstance,
    solution::AbstractDict,
    ext::ACTransmissionExt;
    tol = 0.01,
)::Int
    err_count = 0
    for sc in instance.scenarios
        buses = sc[:bus]
        branches = sc[:ac_branches]
        shunts = sc[:shunts]
        base_mva = sc[:base_mva]

        vm = solution[sc.name]["Bus: Voltage magnitude (p.u.)"]
        va = solution[sc.name]["Bus: Voltage angle (rad)"]
        pf_sol = solution[sc.name]["Line: Base Flow (MW)"]
        qf_sol = solution[sc.name]["Line: Reactive flow (MVAr)"]
        overflow_sol = solution[sc.name]["Line: Base Overflow (MW)"]

        # --- Voltage magnitude bounds ---
        for b in buses, t in 1:instance.time
            if vm[b.name][t] < b.vmin - tol
                @error @sprintf(
                    "Bus %s voltage magnitude below minimum at time %d (%.5f < %.5f)",
                    b.name,
                    t,
                    vm[b.name][t],
                    b.vmin,
                )
                err_count += 1
            end
            if vm[b.name][t] > b.vmax + tol
                @error @sprintf(
                    "Bus %s voltage magnitude above maximum at time %d (%.5f > %.5f)",
                    b.name,
                    t,
                    vm[b.name][t],
                    b.vmax,
                )
                err_count += 1
            end
        end

        # --- Ohm's law and branch constraints ---
        for l in branches, t in 1:instance.time
            p = _ac_branch_params(l)

            vm_fr = vm[l.source.name][t]
            va_fr = va[l.source.name][t]
            vm_to = vm[l.target.name][t]
            va_to = va[l.target.name][t]

            # Expected from-end active power
            expected_pf =
                base_mva * (
                    (p.g + p.g_fr) / p.tm2 * vm_fr^2 +
                    (-p.g * p.tr + p.b * p.ti) / p.tm2 *
                    (vm_fr * vm_to * cos(va_fr - va_to)) +
                    (-p.b * p.tr - p.g * p.ti) / p.tm2 *
                    (vm_fr * vm_to * sin(va_fr - va_to))
                )

            # Expected from-end reactive power
            expected_qf =
                base_mva * (
                    -(p.b + p.b_fr) / p.tm2 * vm_fr^2 -
                    (-p.b * p.tr - p.g * p.ti) / p.tm2 *
                    (vm_fr * vm_to * cos(va_fr - va_to)) +
                    (-p.g * p.tr + p.b * p.ti) / p.tm2 *
                    (vm_fr * vm_to * sin(va_fr - va_to))
                )

            # Expected to-end active power
            expected_pt =
                base_mva * (
                    (p.g + p.g_to) * vm_to^2 +
                    (-p.g * p.tr - p.b * p.ti) / p.tm2 *
                    (vm_to * vm_fr * cos(va_to - va_fr)) +
                    (-p.b * p.tr + p.g * p.ti) / p.tm2 *
                    (vm_to * vm_fr * sin(va_to - va_fr))
                )

            # Expected to-end reactive power
            expected_qt =
                base_mva * (
                    -(p.b + p.b_to) * vm_to^2 -
                    (-p.b * p.tr + p.g * p.ti) / p.tm2 *
                    (vm_to * vm_fr * cos(va_to - va_fr)) +
                    (-p.g * p.tr - p.b * p.ti) / p.tm2 *
                    (vm_to * vm_fr * sin(va_to - va_fr))
                )

            # Verify Ohm's law (from-end active power)
            if abs(pf_sol[l.name][t] - expected_pf) > tol
                @error @sprintf(
                    "Line %s Ohm's law pf violated at time %d (%.4f should be %.4f)",
                    l.name,
                    t,
                    pf_sol[l.name][t],
                    expected_pf,
                )
                err_count += 1
            end

            # Verify Ohm's law (from-end reactive power)
            if abs(qf_sol[l.name][t] - expected_qf) > tol
                @error @sprintf(
                    "Line %s Ohm's law qf violated at time %d (%.4f should be %.4f)",
                    l.name,
                    t,
                    qf_sol[l.name][t],
                    expected_qf,
                )
                err_count += 1
            end

            # --- Flow limits ---
            limit = l.normal_flow_limit[t]
            overflow = overflow_sol[l.name][t]
            max_flow = limit + overflow

            apparent_fr = sqrt(pf_sol[l.name][t]^2 + qf_sol[l.name][t]^2)
            if apparent_fr > max_flow + tol
                @error @sprintf(
                    "Line %s from-end flow exceeds limit at time %d (%.4f > %.4f)",
                    l.name,
                    t,
                    apparent_fr,
                    max_flow,
                )
                err_count += 1
            end

            apparent_to = sqrt(expected_pt^2 + expected_qt^2)
            if apparent_to > max_flow + tol
                @error @sprintf(
                    "Line %s to-end flow exceeds limit at time %d (%.4f > %.4f)",
                    l.name,
                    t,
                    apparent_to,
                    max_flow,
                )
                err_count += 1
            end

            # --- Angle difference bounds ---
            angle_diff = va_fr - va_to
            if isfinite(l.angle_diff_min) && angle_diff < l.angle_diff_min - tol
                @error @sprintf(
                    "Line %s angle difference below minimum at time %d (%.5f < %.5f)",
                    l.name,
                    t,
                    angle_diff,
                    l.angle_diff_min,
                )
                err_count += 1
            end
            if isfinite(l.angle_diff_max) && angle_diff > l.angle_diff_max + tol
                @error @sprintf(
                    "Line %s angle difference above maximum at time %d (%.5f > %.5f)",
                    l.name,
                    t,
                    angle_diff,
                    l.angle_diff_max,
                )
                err_count += 1
            end
        end
    end
    return err_count
end
