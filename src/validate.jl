# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using Printf

bin(x) = [xi > 0.5 for xi in x]

"""
    fix!(instance)

Verifies that the given unit commitment instance is valid and automatically fixes
some validation errors if possible, issuing a warning for each error found.
If a validation error cannot be automatically fixed, issues an exception.

Returns the number of validation errors found.
"""
function fix!(instance::UnitCommitmentInstance)::Int
    n_errors = 0
    
    for g in instance.units
        
        # Startup costs and delays must be increasing
        for s in 2:length(g.startup_categories)
            if g.startup_categories[s].delay <= g.startup_categories[s-1].delay
                prev_value = g.startup_categories[s].delay
                new_value = g.startup_categories[s-1].delay + 1
                @warn "Generator $(g.name) has non-increasing startup delays (category $s). " *
                      "Changing delay: $prev_value → $new_value"
                g.startup_categories[s].delay = new_value
                n_errors += 1
            end
            
            if g.startup_categories[s].cost < g.startup_categories[s-1].cost
                prev_value = g.startup_categories[s].cost
                new_value = g.startup_categories[s-1].cost
                @warn "Generator $(g.name) has decreasing startup cost (category $s). " *
                      "Changing cost: $prev_value → $new_value"
                g.startup_categories[s].cost = new_value
                n_errors += 1
            end

        end
        
        for t in 1:instance.time
            # Production cost curve should be convex
            for k in 2:length(g.cost_segments)
                cost = g.cost_segments[k].cost[t]
                min_cost = g.cost_segments[k-1].cost[t]
                if cost < min_cost - 1e-5
                    @warn "Generator $(g.name) has non-convex production cost curve " *
                          "(segment $k, time $t). Changing cost: $cost → $min_cost"
                    g.cost_segments[k].cost[t] = min_cost
                    n_errors += 1
                end
            end

            # Startup limit must be greater than min_power
            if g.startup_limit < g.min_power[t]
                new_limit = g.min_power[t]
                prev_limit = g.startup_limit
                @warn "Generator $(g.name) has startup limit lower than minimum power. " *
                      "Changing startup limit: $prev_limit → $new_limit"
                g.startup_limit = new_limit
                n_errors += 1
            end
        end
    end
    
    
    return n_errors
end


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

This function is implemented independently from the optimization model in `model.jl`, and
therefore can be used to verify that the model is indeed producing valid solutions. It
can also be used to verify the solutions produced by other optimization packages.
"""
function validate(instance::UnitCommitmentInstance,
                  solution::Union{Dict,OrderedDict};
                 )::Bool
    err_count = 0
    err_count += validate_units(instance, solution)
    err_count += validate_reserve_and_demand(instance, solution)
    
    if err_count > 0
        @error "Found $err_count validation errors"
        return false
    end
    
    return true
end


function validate_units(instance, solution; tol=0.01)
    err_count = 0
    
    for unit in instance.units
        production = solution["Production (MW)"][unit.name]
        reserve = solution["Reserve (MW)"][unit.name]
        actual_production_cost = solution["Production cost (\$)"][unit.name]
        actual_startup_cost = solution["Startup cost (\$)"][unit.name]
        is_on = bin(solution["Is on"][unit.name])
        switch_off = bin(solution["Switch off"][unit.name]) # some formulations may not use this
        
        for t in 1:instance.time
            # Auxiliary variables
            if t == 1
                is_starting_up = (unit.initial_status < 0) && is_on[t]
                is_shutting_down = (unit.initial_status > 0) && !is_on[t]
                ramp_up = max(0, production[t] + reserve[t] - unit.initial_power)
                ramp_down = max(0, unit.initial_power - production[t])
            else
                is_starting_up = !is_on[t-1] && is_on[t]
                is_shutting_down = is_on[t-1] && !is_on[t]
                ramp_up = max(0, production[t] + reserve[t] - production[t-1])
                #ramp_down = max(0, production[t-1] - production[t])
                ramp_down = max(0, production[t-1] + reserve[t-1] - production[t])
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
                @error @sprintf("Unit %s produces negative amount of power at time %d (%.2f)",
                                unit.name, t, production[t])
                err_count += 1
            end
            
            # Verify must-run
            if !is_on[t] && unit.must_run[t]
                @error @sprintf("Must-run unit %s is offline at time %d",
                                unit.name, t)
                err_count += 1
            end
            
            # Verify reserve eligibility
            if !unit.provides_spinning_reserves[t] && reserve[t] > tol
                @error @sprintf("Unit %s is not eligible to provide spinning reserves at time %d",
                                unit.name, t)
                err_count += 1
            end
                
            # If unit is on, must produce at least its minimum power
            if is_on[t] && (production[t] < unit.min_power[t] - tol)
                @error @sprintf("Unit %s produces below its minimum limit at time %d (%.2f < %.2f)",
                                unit.name, t, production[t], unit.min_power[t])
                err_count += 1
            end
            
            # If unit is on, must produce at most its maximum power
            if is_on[t] && (production[t] + reserve[t] > unit.max_power[t] + tol)
                @error @sprintf("Unit %s produces above its maximum limit at time %d (%.2f + %.2f> %.2f)",
                                unit.name, t, production[t], reserve[t], unit.max_power[t])
                err_count += 1
            end
            
            # If unit is off, must produce zero
            if !is_on[t] && production[t] + reserve[t] > tol
                @error @sprintf("Unit %s produces power at time %d while off",
                                unit.name, t)
                err_count += 1
            end
            
            # Startup limit
            if is_starting_up && (ramp_up > unit.startup_limit + tol)
                @error @sprintf("Unit %s exceeds startup limit at time %d (%.2f > %.2f)",
                                unit.name, t, ramp_up, unit.startup_limit)
                err_count += 1
            end

            # Shutdown limit
            if is_shutting_down && (ramp_down > unit.shutdown_limit + tol)
              @error @sprintf("Unit %s exceeds shutdown limit at time %d (%.2f > %.2f)\n\tproduction[t-1] = %.2f\n\treserve[t-1] = %.2f\n\tproduction[t] = %.2f\n\treserve[t] = %.2f\n\tis_on[t-1] = %d\n\tis_on[t] = %d",
                                unit.name, t, ramp_down, unit.shutdown_limit,
                                (t == 1 ? unit.initial_power : production[t-1]), production[t],
                                (t == 1 ? 0. : reserve[t-1]), reserve[t],
                                (t == 1 ? unit.initial_status != nothing && unit.initial_status > 0 : is_on[t-1]), is_on[t]
                               )
                err_count += 1
            end

            # Ramp-up limit
            if !is_starting_up && !is_shutting_down && (ramp_up > unit.ramp_up_limit + tol)
                @error @sprintf("Unit %s exceeds ramp up limit at time %d (%.2f > %.2f)",
                                unit.name, t, ramp_up, unit.ramp_up_limit)
                err_count += 1
            end

            # Ramp-down limit
            if !is_starting_up && !is_shutting_down && (ramp_down > unit.ramp_down_limit + tol)
                @error @sprintf("Unit %s exceeds ramp down limit at time %d (%.2f > %.2f)\n\tproduction[t-1] = %.2f\n\treserve[t-1] = %.2f\n\tproduction[t] = %.2f\n\treserve[t] = %.2f\n\tis_on[t-1] = %d\n\tis_on[t] = %d",
                                unit.name, t, ramp_down, unit.ramp_down_limit,
                                (t == 1 ? unit.initial_power : production[t-1]), production[t],
                                (t == 1 ? 0. : reserve[t-1]), reserve[t],
                                (t == 1 ? unit.initial_status != nothing && unit.initial_status > 0 : is_on[t-1]), is_on[t]
                               )
                err_count += 1
            end
            
            # Verify startup costs & minimum downtime
            if is_starting_up
                
                # Calculate how much time the unit has been offline
                time_down = 0
                for k in 1:(t-1)
                  if !is_on[t - k]
                        time_down += 1
                    else
                        break
                    end
                end
                if t == time_down + 1 && !switch_off[1]
                    # If unit has always been off, then the correct startup cost depends on how long was it off before t = 1
                    # Absent known initial conditions, we assume it was off for the minimum downtime
                    # TODO: verify the formulations are making the same assumption...
                    initial_down = unit.min_downtime
                    if unit.initial_status < 0
                        initial_down = -unit.initial_status
                    end
                    time_down += initial_down
                end
                
                # Calculate startup costs
                for c in unit.startup_categories
                    if time_down >= c.delay
                        startup_cost = c.cost
                    end
                end
                
                # Check minimum downtime
                if time_down < unit.min_downtime
                    @error @sprintf("Unit %s violates minimum downtime at time %d",
                                    unit.name, t)
                    err_count += 1
                end
            end
            
            # Verify minimum uptime
            if is_shutting_down
                
                # Calculate how much time the unit has been online
                time_up = 0
                for k in 1:(t-1)
                    if is_on[t - k]
                        time_up += 1
                    else
                        break
                    end
                end
                if t == time_up + 1
                    initial_up = unit.min_uptime
                    if unit.initial_status > 0
                        initial_up = unit.initial_status
                    end
                    time_up += initial_up
                end
                
                if (t == time_up + 1) && (unit.initial_status > 0)
                    time_up += unit.initial_status
                end
                
                # Check minimum uptime
                if time_up < unit.min_uptime
                    @error @sprintf("Unit %s violates minimum uptime at time %d",
                                    unit.name, t)
                    err_count += 1
                end
            end
            
            # Verify production costs
            if abs(actual_production_cost[t] - production_cost) > 1.00
                @error @sprintf("Unit %s has unexpected production cost at time %d (%.2f should be %.2f)",
                                unit.name, t, actual_production_cost[t], production_cost)
                err_count += 1
            end

            # Verify startup costs
            if abs(actual_startup_cost[t] - startup_cost) > 1.00
                @error @sprintf("Unit %s has unexpected startup cost at time %d (%.2f should be %.2f)",
                                unit.name, t, actual_startup_cost[t], startup_cost)
                err_count += 1
            end
        
        end
    end
    
    return err_count
end


function validate_reserve_and_demand(instance, solution, tol=0.01)
    err_count = 0
    for t in 1:instance.time
        load_curtail = 0
        fixed_load = sum(b.load[t] for b in instance.buses)
        production = sum(solution["Production (MW)"][g.name][t]
                         for g in instance.units)
        if "Load curtail (MW)" in keys(solution)
            load_curtail = sum(solution["Load curtail (MW)"][b.name][t]
                               for b in instance.buses)
        end
        balance = fixed_load - load_curtail - production
        
        # Verify that production equals demand
        if abs(balance) > tol
            @error @sprintf("Non-zero power balance at time %d (%.2f - %.2f - %.2f != 0)",
                            t, fixed_load, load_curtail, production)
            err_count += 1
        end
        
        # Verify spinning reserves
        reserve = sum(solution["Reserve (MW)"][g.name][t] for g in instance.units)
        if reserve < instance.reserves.spinning[t] - tol
            @error @sprintf("Insufficient spinning reserves at time %d (%.2f should be %.2f)",
                            t, reserve, instance.reserves.spinning[t])
            err_count += 1
        end
    end
    
    return err_count
end
 