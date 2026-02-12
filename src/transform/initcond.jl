# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
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
    # Process first scenario
    _generate_initial_conditions!(instance.scenarios[1], optimizer)

    # Copy initial conditions to remaining scenarios
    sc1 = instance.scenarios[1]
    for (si, sc) in enumerate(instance.scenarios)
        si > 1 || continue
        if haskey(sc, :thermal)
            for (i, g) in enumerate(sc[:thermal])
                g_ref = sc1[:thermal][i]
                g.initial_power = g_ref.initial_power
                g.initial_status = g_ref.initial_status
            end
        end
    end
end

function _generate_initial_conditions!(
    sc::UnitCommitmentScenario,
    optimizer,
)::Nothing
    G = get(sc, :thermal, [])
    B = sc[:bus]
    PU = get(sc, :profiled, [])
    SU = get(sc, :storage, [])
    PS = get(sc, :psload, [])
    t = 1
    mip = JuMP.Model(optimizer)

    # Decision variables: thermal units
    @variable(mip, is_on[G], Bin)
    @variable(mip, prod_thermal[G] >= 0)

    # Decision variables: profiled units
    @variable(mip, prod_profiled[PU])

    # Decision variables: storage units
    @variable(mip, discharge[SU] >= 0)
    @variable(mip, charge[SU] >= 0)

    # Decision variables: price-sensitive loads
    @variable(mip, prod_ps[PS] >= 0)

    # Constraints: thermal units
    @constraint(mip, [g in G], prod_thermal[g] >= g.min_power[t] * is_on[g])
    @constraint(mip, [g in G], prod_thermal[g] <= g.max_power[t] * is_on[g])
    for g in G
        if g.must_run[t]
            @constraint(mip, is_on[g] == 1)
        end
    end

    # Constraints: profiled units
    @constraint(mip, [k in PU], prod_profiled[k] >= k.min_power[t])
    @constraint(mip, [k in PU], prod_profiled[k] <= k.max_power[t])

    # Constraints: storage units
    @constraint(mip, [su in SU], charge[su] <= su.max_charge_rate[t])
    @constraint(mip, [su in SU], discharge[su] <= su.max_discharge_rate[t])

    # Constraints: price-sensitive loads
    @constraint(mip, [ps in PS], prod_ps[ps] <= ps.demand[t])

    # Constraint: production equals demand
    @constraint(
        mip,
        power_balance,
        sum(b.load[t] for b in B) - sum(prod_ps[ps] for ps in PS) ==
        sum(prod_thermal[g] for g in G) +
        sum(prod_profiled[k] for k in PU) +
        sum(discharge[su] - charge[su] for su in SU),
    )

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
    @objective(
        mip,
        Min,
        sum(prod_thermal[g] * cost_slope(g) for g in G) +
        sum(prod_profiled[k] * k.cost[t] for k in PU) +
        sum(
            discharge[su] * su.discharge_cost[t] +
            charge[su] * su.charge_cost[t]
            for su in SU;
            init = 0.0,
        ) -
        sum(prod_ps[ps] * ps.revenue[t] for ps in PS; init = 0.0),
    )

    JuMP.optimize!(mip)

    for g in G
        if JuMP.value(is_on[g]) > 0
            g.initial_power = JuMP.value(prod_thermal[g])
            g.initial_status = 24
        else
            g.initial_power = 0
            g.initial_status = -24
        end
    end
    return
end
