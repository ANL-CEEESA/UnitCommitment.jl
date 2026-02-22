# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using Printf

function validate(
    instance::UnitCommitmentInstance,
    solution::AbstractDict,
    ::ThermalExt,
)::Int
    err_count = _validate_units(instance, solution)
    err_count += _validate_reserves(instance, solution)
    return err_count
end

function _validate_units(instance::UnitCommitmentInstance, solution; tol = 0.01)
    err_count = 0
    for sc in instance.scenarios
        for unit in sc[:thermal]
            production =
                solution[sc.name]["Thermal: Production (MW)"][unit.name]
            # Spinning reserve total (for online checks)
            spinning = [r for r in unit.reserves if r.type == :spinning]
            spinning_reserve = [0.0 for _ in 1:instance.time]
            if !isempty(spinning)
                spinning_reserve += sum(
                    solution[sc.name]["Reserve: Provided (MW)"][r.name][unit.name]
                    for r in spinning
                )
            end

            # Non-spinning reserve total (for offline checks)
            non_spinning = [r for r in unit.reserves if r.type == :non_spinning]
            ns_reserve = [0.0 for _ in 1:instance.time]
            if !isempty(non_spinning)
                ns_reserve += sum(
                    solution[sc.name]["Reserve: Provided (MW)"][r.name][unit.name]
                    for r in non_spinning
                )
            end
            reserve = spinning_reserve
            actual_production_cost =
                solution[sc.name]["Thermal: Production cost (\$)"][unit.name]
            actual_startup_cost =
                solution[sc.name]["Thermal: Startup cost (\$)"][unit.name]
            is_on = bin(solution[sc.name]["Thermal: Is on"][unit.name])

            for t in 1:instance.time
                # Auxiliary variables
                if t == 1
                    is_starting_up = (unit.initial_status < 0) && is_on[t]
                    is_shutting_down = (unit.initial_status > 0) && !is_on[t]
                    ramp_up =
                        max(0, production[t] + reserve[t] - unit.initial_power)
                    ramp_down = max(0, unit.initial_power - production[t])
                else
                    is_starting_up = !is_on[t-1] && is_on[t]
                    is_shutting_down = is_on[t-1] && !is_on[t]
                    ramp_up =
                        max(0, production[t] + reserve[t] - production[t-1])
                    ramp_down = max(0, production[t-1] - production[t])
                end

                # Compute production costs
                production_cost, startup_cost = 0, 0
                if is_on[t]
                    production_cost += unit.min_power_cost[t]
                    residual = max(0, production[t] - unit.min_power[t])
                    for s in unit.cost_segments
                        cleared = min(residual, s.mw[t])
                        production_cost += cleared * s.cost[t]
                        residual = max(0, residual - s.mw[t])
                    end
                end

                # Production should be non-negative
                if production[t] < -tol
                    @error @sprintf(
                        "Unit %s produces negative amount of power at time %d (%.2f)",
                        unit.name,
                        t,
                        production[t]
                    )
                    err_count += 1
                end

                # Verify must-run
                if !is_on[t] && unit.must_run[t]
                    @error @sprintf(
                        "Must-run unit %s is offline at time %d",
                        unit.name,
                        t
                    )
                    err_count += 1
                end

                # Verify reserve eligibility
                for r in sc[:reserves]
                    if unit ∉ r.thermal_units && (
                        unit in keys(
                            solution[sc.name]["Reserve: Provided (MW)"][r.name],
                        )
                    )
                        @error @sprintf(
                            "Unit %s is not eligible to provide reserve %s",
                            unit.name,
                            r.name,
                        )
                        err_count += 1
                    end
                end

                # If unit is on, must produce at least its minimum power
                if is_on[t] && (production[t] < unit.min_power[t] - tol)
                    @error @sprintf(
                        "Unit %s produces below its minimum limit at time %d (%.2f < %.2f)",
                        unit.name,
                        t,
                        production[t],
                        unit.min_power[t]
                    )
                    err_count += 1
                end

                # If unit is on, must produce at most its maximum power
                if is_on[t] &&
                   (production[t] + reserve[t] > unit.max_power[t] + tol)
                    @error @sprintf(
                        "Unit %s produces above its maximum limit at time %d (%.2f + %.2f> %.2f)",
                        unit.name,
                        t,
                        production[t],
                        reserve[t],
                        unit.max_power[t]
                    )
                    err_count += 1
                end

                # If unit is off, must produce zero
                if !is_on[t] && production[t] + reserve[t] > tol
                    @error @sprintf(
                        "Unit %s produces power at time %d while off (%.2f + %.2f > 0)",
                        unit.name,
                        t,
                        production[t],
                        reserve[t],
                    )
                    err_count += 1
                end

                # Online units must not provide non-spinning reserves
                if is_on[t] && ns_reserve[t] > tol
                    @error @sprintf(
                        "Online unit %s provides non-spinning reserve at time %d (%.2f > 0)",
                        unit.name,
                        t,
                        ns_reserve[t],
                    )
                    err_count += 1
                end

                # Offline non-spinning reserve bounded by capacity
                if !is_on[t] && ns_reserve[t] > unit.non_spinning_capacity + tol
                    @error @sprintf(
                        "Unit %s exceeds non-spinning reserve capacity at time %d (%.2f > %.2f)",
                        unit.name,
                        t,
                        ns_reserve[t],
                        unit.non_spinning_capacity,
                    )
                    err_count += 1
                end

                # Startup limit
                if is_starting_up && (ramp_up > unit.startup_limit + tol)
                    @error @sprintf(
                        "Unit %s exceeds startup limit at time %d (%.2f > %.2f)",
                        unit.name,
                        t,
                        ramp_up,
                        unit.startup_limit
                    )
                    err_count += 1
                end

                # Shutdown limit
                if is_shutting_down && (ramp_down > unit.shutdown_limit + tol)
                    @error @sprintf(
                        "Unit %s exceeds shutdown limit at time %d (%.2f > %.2f)",
                        unit.name,
                        t,
                        ramp_down,
                        unit.shutdown_limit
                    )
                    err_count += 1
                end

                # Ramp-up limit
                if !is_starting_up &&
                   !is_shutting_down &&
                   (ramp_up > unit.ramp_up_limit + tol)
                    @error @sprintf(
                        "Unit %s exceeds ramp up limit at time %d (%.2f > %.2f)",
                        unit.name,
                        t,
                        ramp_up,
                        unit.ramp_up_limit
                    )
                    err_count += 1
                end

                # Ramp-down limit
                if !is_starting_up &&
                   !is_shutting_down &&
                   (ramp_down > unit.ramp_down_limit + tol)
                    @error @sprintf(
                        "Unit %s exceeds ramp down limit at time %d (%.2f > %.2f)",
                        unit.name,
                        t,
                        ramp_down,
                        unit.ramp_down_limit
                    )
                    err_count += 1
                end

                # Verify startup costs & minimum downtime
                if is_starting_up

                    # Calculate how much time the unit has been offline
                    time_down = 0
                    for k in 1:(t-1)
                        if !is_on[t-k]
                            time_down += 1
                        else
                            break
                        end
                    end
                    if (t == time_down + 1) && (unit.initial_status < 0)
                        time_down -= unit.initial_status
                    end

                    # Calculate startup costs
                    for c in unit.startup_categories
                        if time_down >= c.delay
                            startup_cost = c.cost
                        end
                    end

                    # Check minimum downtime
                    if time_down < unit.min_downtime
                        @error @sprintf(
                            "Unit %s violates minimum downtime at time %d",
                            unit.name,
                            t
                        )
                        err_count += 1
                    end
                end

                # Verify minimum uptime
                if is_shutting_down

                    # Calculate how much time the unit has been online
                    time_up = 0
                    for k in 1:(t-1)
                        if is_on[t-k]
                            time_up += 1
                        else
                            break
                        end
                    end
                    if (t == time_up + 1) && (unit.initial_status > 0)
                        time_up += unit.initial_status
                    end

                    # Check minimum uptime
                    if time_up < unit.min_uptime
                        @error @sprintf(
                            "Unit %s violates minimum uptime at time %d",
                            unit.name,
                            t
                        )
                        err_count += 1
                    end
                end

                # Verify production costs
                if abs(actual_production_cost[t] - production_cost) > 1.00
                    @error @sprintf(
                        "Unit %s has unexpected production cost at time %d (%.2f should be %.2f)",
                        unit.name,
                        t,
                        actual_production_cost[t],
                        production_cost
                    )
                    err_count += 1
                end

                # Verify startup costs
                if abs(actual_startup_cost[t] - startup_cost) > 1.00
                    @error @sprintf(
                        "Unit %s has unexpected startup cost at time %d (%.2f should be %.2f)",
                        unit.name,
                        t,
                        actual_startup_cost[t],
                        startup_cost
                    )
                    err_count += 1
                end
            end
        end
    end
    return err_count
end

function _validate_reserves(instance, solution, tol = 0.01)
    err_count = 0
    for sc in instance.scenarios
        for t in 1:instance.time
            for r in sc[:reserves]
                # Direct provision
                provided = sum(
                    solution[sc.name]["Reserve: Provided (MW)"][r.name][g.name][t]
                    for g in r.thermal_units;
                    init = 0.0,
                )
                # Cascading provision from descendants
                for d in r.descendants
                    provided += sum(
                        solution[sc.name]["Reserve: Provided (MW)"][d.name][g.name][t]
                        for g in d.thermal_units;
                        init = 0.0,
                    )
                end
                shortfall =
                    solution[sc.name]["Reserve: Shortfall (MW)"][r.name][t]
                required = r.amount[t]

                if provided + shortfall < required - tol
                    @error @sprintf(
                        "Insufficient reserve %s at time %d (%.2f + %.2f < %.2f)",
                        r.name,
                        t,
                        provided,
                        shortfall,
                        required,
                    )
                    err_count += 1
                end
            end
        end
    end

    return err_count
end
