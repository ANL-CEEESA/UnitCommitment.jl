# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

"""
    repair!(instance)

Verifies that the given unit commitment instance is valid and automatically
fixes some validation errors if possible, issuing a warning for each error
found. If a validation error cannot be automatically fixed, issues an
exception.

Returns the number of validation errors found.
"""
function repair!(instance::UnitCommitmentInstance)::Int
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

export repair!
