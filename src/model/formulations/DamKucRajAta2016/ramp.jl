# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

function _add_ramp_eqs!(
    model::JuMP.Model,
    g::Unit,
    formulation_prod_vars::Gar1962.ProdVars,
    formulation_ramping::DamKucRajAta2016.Ramping,
    formulation_status_vars::Gar1962.StatusVars,
    sc::UnitCommitmentScenario,
)::Nothing
    # TODO: Move upper case constants to model[:instance]
    RESERVES_WHEN_START_UP = true
    RESERVES_WHEN_RAMP_UP = true
    RESERVES_WHEN_RAMP_DOWN = true
    RESERVES_WHEN_SHUT_DOWN = true
    known_initial_conditions = true
    is_initially_on = (g.initial_status > 0)
    SU = g.startup_limit
    SD = g.shutdown_limit
    RU = g.ramp_up_limit
    RD = g.ramp_down_limit
    gn = g.name
    eq_str_ramp_down = _init(model, :eq_str_ramp_down)
    eq_str_ramp_up = _init(model, :eq_str_ramp_up)
    reserve = _total_reserves(model, g, sc)

    # Gar1962.ProdVars
    prod_above = model[:prod_above]

    # Gar1962.StatusVars
    is_on = model[:is_on]
    switch_off = model[:switch_off]
    switch_on = model[:switch_on]

    for t in 1:model[:instance].time
        time_invariant =
            (t > 1) ? (abs(g.min_power[t] - g.min_power[t-1]) < 1e-7) : true

        # if t > 1 && !time_invariant
        #     @warn(
        #         "Ramping according to Damcı-Kurt et al. (2016) requires " *
        #         "time-invariant minimum power. This does not hold for " *
        #         "generator $(gn): min_power[$t] = $(g.min_power[t]); " *
        #         "min_power[$(t-1)] = $(g.min_power[t-1]). Reverting to " *
        #         "Arroyo and Conejo (2000) formulation for this generator.",
        #     )
        # end

        max_prod_this_period =
            prod_above[sc.name, gn, t] +
            (RESERVES_WHEN_START_UP || RESERVES_WHEN_RAMP_UP ? reserve[t] : 0.0)
        min_prod_last_period = 0.0
        if t > 1 && time_invariant
            min_prod_last_period = prod_above[sc.name, gn, t-1]

            # Equation (35) in Kneuven et al. (2020)
            # Sparser version of (24)
            eq_str_ramp_up[sc.name, gn, t] = @constraint(
                model,
                max_prod_this_period - min_prod_last_period <=
                (SU - g.min_power[t] - RU) * switch_on[gn, t] +
                RU * is_on[gn, t]
            )
        elseif (t == 1 && is_initially_on) || (t > 1 && !time_invariant)
            if t > 1
                min_prod_last_period =
                    prod_above[sc.name, gn, t-1] +
                    g.min_power[t-1] * is_on[gn, t-1]
            else
                min_prod_last_period = max(g.initial_power, 0.0)
            end

            # Add the min prod at time t back in to max_prod_this_period to get _total_ production
            # (instead of using the amount above minimum, as min prod for t < 1 is unknown)
            max_prod_this_period += g.min_power[t] * is_on[gn, t]

            # Modified version of equation (35) in Kneuven et al. (2020)
            # Equivalent to (24)
            eq_str_ramp_up[sc.name, gn, t] = @constraint(
                model,
                max_prod_this_period - min_prod_last_period <=
                (SU - RU) * switch_on[gn, t] + RU * is_on[gn, t]
            )
        end

        max_prod_last_period =
            min_prod_last_period + (
                t > 1 && (RESERVES_WHEN_SHUT_DOWN || RESERVES_WHEN_RAMP_DOWN) ?
                reserve[t-1] : 0.0
            )
        min_prod_this_period = prod_above[sc.name, gn, t]
        on_last_period = 0.0
        if t > 1
            on_last_period = is_on[gn, t-1]
        elseif (known_initial_conditions && g.initial_status > 0)
            on_last_period = 1.0
        end

        if t > 1 && time_invariant
            # Equation (36) in Kneuven et al. (2020)
            eq_str_ramp_down[sc.name, gn, t] = @constraint(
                model,
                max_prod_last_period - min_prod_this_period <=
                (SD - g.min_power[t] - RD) * switch_off[gn, t] +
                RD * on_last_period
            )
        elseif (t == 1 && is_initially_on) || (t > 1 && !time_invariant)
            # Add back in min power
            min_prod_this_period += g.min_power[t] * is_on[gn, t]

            # Modified version of equation (36) in Kneuven et al. (2020)
            # Equivalent to (25)
            eq_str_ramp_down[sc.name, gn, t] = @constraint(
                model,
                max_prod_last_period - min_prod_this_period <=
                (SD - RD) * switch_off[gn, t] + RD * on_last_period
            )
        end
    end
end
