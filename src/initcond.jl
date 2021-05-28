# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using JuMP

"""
    generate_initial_conditions!(instance, optimizer)

Generates feasible initial conditions for the given instance, by constructing
and solving a single-period mixed-integer optimization problem, using the given
optimizer. The instance is modified in-place.
"""
function generate_initial_conditions!(
    instance::UnitCommitmentInstance,
    optimizer,
)::Nothing
    G = instance.units
    B = instance.buses
    t = 1
    mip = JuMP.Model(optimizer)

    # Decision variables
    @variable(mip, x[G], Bin)
    @variable(mip, p[G] >= 0)

    # Constraint: Minimum power
    @constraint(mip, min_power[g in G], p[g] >= g.min_power[t] * x[g])

    # Constraint: Maximum power
    @constraint(mip, max_power[g in G], p[g] <= g.max_power[t] * x[g])

    # Constraint: Production equals demand
    @constraint(
        mip,
        power_balance,
        sum(b.load[t] for b in B) == sum(p[g] for g in G)
    )

    # Constraint: Must run
    for g in G
        if g.must_run[t]
            @constraint(mip, x[g] == 1)
        end
    end

    # Objective function
    function cost_slope(g)
        mw = g.min_power[t]
        c = g.min_power_cost[t]
        for k in g.cost_segments
            mw += k.mw[t]
            c += k.mw[t] * k.cost[t]
        end
        if mw < 1e-3
            return 0.0
        else
            return c / mw
        end
    end
    @objective(mip, Min, sum(p[g] * cost_slope(g) for g in G))

    JuMP.optimize!(mip)

    for g in G
        if JuMP.value(x[g]) > 0
            g.initial_power = JuMP.value(p[g])
            g.initial_status = 24
        else
            g.initial_power = 0
            g.initial_status = -24
        end
    end
    return
end
