# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using Printf

function validate!(
    instance::UnitCommitmentInstance,
    solution::AbstractDict,
    ::StorageExt;
    tol = 0.01,
)::Int
    err_count = 0

    for sc in instance.scenarios
        for su in sc.data[:storage]
            storage_level = solution[sc.name]["Storage: Level (MWh)"][su.name]
            charge_rate =
                solution[sc.name]["Storage: Charging rate (MW)"][su.name]
            discharge_rate =
                solution[sc.name]["Storage: Discharging rate (MW)"][su.name]
            actual_charge_cost =
                solution[sc.name]["Storage: Charging cost (\$)"][su.name]
            actual_discharge_cost =
                solution[sc.name]["Storage: Discharging cost (\$)"][su.name]
            is_charging =
                bin(solution[sc.name]["Storage: Is charging"][su.name])
            is_discharging =
                bin(solution[sc.name]["Storage: Is discharging"][su.name])
            is_investable = su.invest[1] > 0.0
            invest_status =
                is_investable ?
                bin(solution[sc.name]["Storage: Investment status"][su.name]) :
                nothing
            # time in hours
            time_step = sc.time_step / 60

            for t in 1:instance.time
                # Unit must store at least its minimum level
                effective_min =
                    is_investable ? su.min_level[t] * invest_status[t] :
                    su.min_level[t]
                if storage_level[t] < effective_min - tol
                    @error @sprintf(
                        "Storage unit %s stores below its minimum level at time %d (%.2f < %.2f)",
                        su.name,
                        t,
                        storage_level[t],
                        effective_min
                    )
                    err_count += 1
                end
                # Unit must store at most its maximum level
                effective_max =
                    is_investable ? su.max_level[t] * invest_status[t] :
                    su.max_level[t]
                if storage_level[t] > effective_max + tol
                    @error @sprintf(
                        "Storage unit %s stores above its maximum level at time %d (%.2f > %.2f)",
                        su.name,
                        t,
                        storage_level[t],
                        effective_max
                    )
                    err_count += 1
                end

                if t == instance.time
                    # Unit must store at least its minimum level at last time period
                    if storage_level[t] < su.min_ending_level - tol
                        @error @sprintf(
                            "Storage unit %s stores below its minimum ending level (%.2f < %.2f)",
                            su.name,
                            storage_level[t],
                            su.min_ending_level
                        )
                        err_count += 1
                    end
                    # Unit must store at most its maximum level at last time period
                    if storage_level[t] > su.max_ending_level + tol
                        @error @sprintf(
                            "Storage unit %s stores above its maximum ending level (%.2f > %.2f)",
                            su.name,
                            storage_level[t],
                            su.max_ending_level
                        )
                        err_count += 1
                    end
                end

                # Unit must follow the energy transition constraint
                prev_level = t == 1 ? su.initial_level : storage_level[t-1]
                current_level =
                    (1 - su.loss_factor[t]) * prev_level +
                    time_step * (
                        charge_rate[t] * su.charge_efficiency[t] -
                        discharge_rate[t] / su.discharge_efficiency[t]
                    )
                if abs(storage_level[t] - current_level) > tol
                    @error @sprintf(
                        "Storage unit %s has unexpected level at time %d (%.2f should be %.2f)",
                        su.name,
                        t,
                        storage_level[t],
                        current_level
                    )
                    err_count += 1
                end

                # Unit cannot simultaneous charge and discharge if it is not allowed
                if !su.simultaneous_charge_and_discharge[t] &&
                   is_charging[t] &&
                   is_discharging[t]
                    @error @sprintf(
                        "Storage unit %s is charging and discharging simultaneous at time %d",
                        su.name,
                        t
                    )
                    err_count += 1
                end

                # Unit must charge at least its minimum rate
                if is_charging[t] &&
                   (charge_rate[t] < su.min_charge_rate[t] - tol)
                    @error @sprintf(
                        "Storage unit %s charges below its minimum limit at time %d (%.2f < %.2f)",
                        su.name,
                        t,
                        charge_rate[t],
                        su.min_charge_rate[t]
                    )
                    err_count += 1
                end
                # Unit must charge at most its maximum rate
                if is_charging[t] &&
                   (charge_rate[t] > su.max_charge_rate[t] + tol)
                    @error @sprintf(
                        "Storage unit %s charges above its maximum limit at time %d (%.2f > %.2f)",
                        su.name,
                        t,
                        charge_rate[t],
                        su.max_charge_rate[t]
                    )
                    err_count += 1
                end
                # Unit must have zero charge when it is not charging
                if !is_charging[t] && (charge_rate[t] > tol)
                    @error @sprintf(
                        "Storage unit %s charges power at time %d while not charging (%.2f > 0)",
                        su.name,
                        t,
                        charge_rate[t]
                    )
                    err_count += 1
                end

                # Unit must discharge at least its minimum rate
                if is_discharging[t] &&
                   (discharge_rate[t] < su.min_discharge_rate[t] - tol)
                    @error @sprintf(
                        "Storage unit %s discharges below its minimum limit at time %d (%.2f < %.2f)",
                        su.name,
                        t,
                        discharge_rate[t],
                        su.min_discharge_rate[t]
                    )
                    err_count += 1
                end
                # Unit must discharge at most its maximum rate
                if is_discharging[t] &&
                   (discharge_rate[t] > su.max_discharge_rate[t] + tol)
                    @error @sprintf(
                        "Storage unit %s discharges above its maximum limit at time %d (%.2f > %.2f)",
                        su.name,
                        t,
                        discharge_rate[t],
                        su.max_discharge_rate[t]
                    )
                    err_count += 1
                end
                # Unit must have zero discharge when it is not discharging
                if !is_discharging[t] && (discharge_rate[t] > tol)
                    @error @sprintf(
                        "Storage unit %s discharges power at time %d while not discharging (%.2f > 0)",
                        su.name,
                        t,
                        discharge_rate[t]
                    )
                    err_count += 1
                end

                # Compute storage costs
                charge_cost = su.charge_cost[t] * charge_rate[t]
                discharge_cost = su.discharge_cost[t] * discharge_rate[t]
                # Compare costs
                if abs(actual_charge_cost[t] - charge_cost) > tol
                    @error @sprintf(
                        "Storage unit %s has unexpected charge cost at time %d (%.2f should be %.2f)",
                        su.name,
                        t,
                        actual_charge_cost[t],
                        charge_cost
                    )
                    err_count += 1
                end
                if abs(actual_discharge_cost[t] - discharge_cost) > tol
                    @error @sprintf(
                        "Storage unit %s has unexpected discharge cost at time %d (%.2f should be %.2f)",
                        su.name,
                        t,
                        actual_discharge_cost[t],
                        discharge_cost
                    )
                    err_count += 1
                end
            end

            # Investment must be non-decreasing
            if is_investable
                for t in 2:instance.time
                    if invest_status[t-1] > invest_status[t] + tol
                        @error @sprintf(
                            "Storage unit %s has decreasing investment status at time %d (%.2f > %.2f)",
                            su.name,
                            t,
                            invest_status[t-1],
                            invest_status[t]
                        )
                        err_count += 1
                    end
                end
            end
        end
    end
    return err_count
end
