# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using Printf

bin(x) = [xi > 0.5 for xi in x]

function validate(instance_filename::String, solution_filename::String)
    instance = UnitCommitment.read(instance_filename)
    solution = JSON.parse(open(solution_filename))
    return validate(instance, solution)
end

"""
    validate(instance, solution)::Bool

Verifies that the given solution is feasible for the problem. If feasible,
silently returns true. In infeasible, returns false and prints the validation
errors to the screen.

This function is implemented independently from the optimization model in
`model.jl`, and therefore can be used to verify that the model is indeed
producing valid solutions. It can also be used to verify the solutions produced
by other optimization packages.
"""
function validate(
    instance::UnitCommitmentInstance,
    solution::Union{Dict,OrderedDict},
)::Bool
    err_count = 0
    err_count += _validate_units(instance, solution)
    err_count += _validate_reserve_and_demand(instance, solution)

    if err_count > 0
        @error "Found $err_count validation errors"
        return false
    end

    return true
end

function _validate_units(instance, solution; tol = 0.01)
    err_count = 0

    for unit in instance.units
        production = solution["Production (MW)"][unit.name]
        reserve = solution["Reserve (MW)"][unit.name]
        actual_production_cost = solution["Production cost (\$)"][unit.name]
        actual_startup_cost = solution["Startup cost (\$)"][unit.name]
        is_on = bin(solution["Is on"][unit.name])

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
                ramp_up = max(0, production[t] + reserve[t] - production[t-1])
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
            if !unit.provides_spinning_reserves[t] && reserve[t] > tol
                @error @sprintf(
                    "Unit %s is not eligible to provide spinning reserves at time %d",
                    unit.name,
                    t
                )
                err_count += 1
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
                    "Unit %s produces power at time %d while off",
                    unit.name,
                    t
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

    return err_count
end

function _validate_reserve_and_demand(instance, solution, tol = 0.01)
    err_count = 0
    for t in 1:instance.time
        load_curtail = 0
        fixed_load = sum(b.load[t] for b in instance.buses)
        ps_load = 0
        if length(instance.price_sensitive_loads) > 0
            ps_load = sum(
                solution["Price-sensitive loads (MW)"][ps.name][t] for
                ps in instance.price_sensitive_loads
            )
        end
        production =
            sum(solution["Production (MW)"][g.name][t] for g in instance.units)
        if "Load curtail (MW)" in keys(solution)
            load_curtail = sum(
                solution["Load curtail (MW)"][b.name][t] for
                b in instance.buses
            )
        end
        balance = fixed_load - load_curtail - production + ps_load

        # Verify that production equals demand
        if abs(balance) > tol
            @error @sprintf(
                "Non-zero power balance at time %d (%.2f + %.2f - %.2f - %.2f != 0)",
                t,
                fixed_load,
                ps_load,
                load_curtail,
                production,
            )
            err_count += 1
        end

        
        # Verify flexiramp solutions only if either of the up-flexiramp and  
        # down-flexiramp requirements is not a default array of zeros
        if instance.reserves.upflexiramp != zeros(instance.time) || instance.reserves.dwflexiramp != zeros(instance.time)
            upflexiramp =
            sum(solution["Up-flexiramp (MW)"][g.name][t] for g in instance.units)
            upflexiramp_shortfall =
                (instance.flexiramp_shortfall_penalty[t] >= 0) ?
                solution["Up-flexiramp shortfall (MW)"][t] : 0

            if upflexiramp + upflexiramp_shortfall < instance.reserves.upflexiramp[t] - tol
                @error @sprintf(
                    "Insufficient up-flexiramp at time %d (%.2f + %.2f should be %.2f)",
                    t,
                    upflexiramp,
                    upflexiramp_shortfall,
                    instance.reserves.upflexiramp[t],
                )
                err_count += 1
            end
        

            dwflexiramp =
                sum(solution["Down-flexiramp (MW)"][g.name][t] for g in instance.units)
            dwflexiramp_shortfall =
                (instance.flexiramp_shortfall_penalty[t] >= 0) ?
                solution["Down-flexiramp shortfall (MW)"][t] : 0

            if dwflexiramp + dwflexiramp_shortfall < instance.reserves.dwflexiramp[t] - tol
                @error @sprintf(
                    "Insufficient down-flexiramp at time %d (%.2f + %.2f should be %.2f)",
                    t,
                    dwflexiramp,
                    dwflexiramp_shortfall,
                    instance.reserves.dwflexiramp[t],
                )
                err_count += 1
            end
        # Verify spinning reserve solutions only if both up-flexiramp and  
        # down-flexiramp requirements are arrays of zeros.
        else
            reserve =
                sum(solution["Reserve (MW)"][g.name][t] for g in instance.units)
            reserve_shortfall =
                (instance.shortfall_penalty[t] >= 0) ?
                solution["Reserve shortfall (MW)"][t] : 0

            if reserve + reserve_shortfall < instance.reserves.spinning[t] - tol
                @error @sprintf(
                    "Insufficient spinning reserves at time %d (%.2f + %.2f should be %.2f)",
                    t,
                    reserve,
                    reserve_shortfall,
                    instance.reserves.spinning[t],
                )
                err_count += 1
            end
        end
 
    end

    return err_count
end
