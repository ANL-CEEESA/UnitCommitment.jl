# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

function _add_thermal_constr_ramping!(
    model::JuMP.Model,
    instance::UnitCommitmentInstance,
    ::MorLatRam2013.Ramping,
)
    for sc in instance.scenarios, g in sc[:thermal]
        gn = g.name
        prod_above = model[:prod_above]
        reserve = _total_spinning_reserves(model, instance, g, sc)

        eq_ramp_down = _init(model, :eq_ramp_down)
        eq_ramp_up = _init(model, :eq_ramp_up)

        if g.initial_status > 0
            if g.initial_power < g.min_power[1]
                error(
                    "MorLatRam2013.Ramping: Initial power cannot be lower than initial minimum power (generator $(gn))",
                )
            end
            eq_ramp_up[sc.name, gn, 1] = @constraint(
                model,
                prod_above[sc.name, gn, 1] + reserve[1] -
                (g.initial_power - g.min_power[1]) <= g.ramp_up_limit
            )
            eq_ramp_down[sc.name, gn, 1] = @constraint(
                model,
                (g.initial_power - g.min_power[1]) -
                prod_above[sc.name, gn, 1] <= g.ramp_down_limit
            )
        end

        for t in 2:instance.time
            if !(g.min_power[t] ≈ g.min_power[t-1])
                error(
                    "MorLatRam2013.Ramping: Time-varying minimum power is not supported (generator $(gn), time $t)",
                )
            end

            # Equation (26) in Kneuven et al. (2020)
            eq_ramp_up[sc.name, gn, t] = @constraint(
                model,
                prod_above[sc.name, gn, t] + reserve[t] -
                prod_above[sc.name, gn, t-1] <= g.ramp_up_limit
            )

            # Equation (27) in Kneuven et al. (2020)
            eq_ramp_down[sc.name, gn, t] = @constraint(
                model,
                prod_above[sc.name, gn, t-1] - prod_above[sc.name, gn, t] <=
                g.ramp_down_limit
            )
        end
    end
end
