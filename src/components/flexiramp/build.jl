# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

# Formulation described in:
#
#     B. Wang and B. F. Hobbs, "Real-Time Markets for Flexiramp: A Stochastic
#     Unit Commitment-Based Analysis," in IEEE Transactions on Power Systems,
#     vol. 31, no. 2, pp. 846-860, March 2016, doi: 10.1109/TPWRS.2015.2411268.

function build_model(
    model::JuMP.Model,
    instance::UnitCommitmentInstance,
    ::FlexirampExt,
)::Nothing
    T = instance.time

    mfg = _init(model, :mfg)
    upflexiramp = _init(model, :upflexiramp)
    dwflexiramp = _init(model, :dwflexiramp)
    upflexiramp_shortfall = _init(model, :upflexiramp_shortfall)
    dwflexiramp_shortfall = _init(model, :dwflexiramp_shortfall)

    is_on = model[:is_on]
    prod_above = model[:prod_above]

    eq_mfg_lb = _init(model, :eq_mfg_lb)
    eq_mfg_ub = _init(model, :eq_mfg_ub)
    eq_dwflexi_lb = _init(model, :eq_dwflexi_lb)
    eq_dwflexi_ub = _init(model, :eq_dwflexi_ub)
    eq_upflexi_lb = _init(model, :eq_upflexi_lb)
    eq_upflexi_ub = _init(model, :eq_upflexi_ub)
    eq_ramp_up = _init(model, :eq_ramp_up)
    eq_mfg_shutdown = _init(model, :eq_mfg_shutdown)
    eq_ramp_down = _init(model, :eq_ramp_down)
    eq_upflexi_ramp_lb = _init(model, :eq_upflexi_ramp_lb)
    eq_upflexi_ramp_ub = _init(model, :eq_upflexi_ramp_ub)
    eq_dwflexi_ramp_lb = _init(model, :eq_dwflexi_ramp_lb)
    eq_dwflexi_ramp_ub = _init(model, :eq_dwflexi_ramp_ub)
    eq_upflexi_power_lb = _init(model, :eq_upflexi_power_lb)
    eq_upflexi_power_ub = _init(model, :eq_upflexi_power_ub)
    eq_dwflexi_power_lb = _init(model, :eq_dwflexi_power_lb)
    eq_dwflexi_power_ub = _init(model, :eq_dwflexi_power_ub)
    eq_min_flexiramp_up = _init(model, :eq_min_flexiramp_up)
    eq_min_flexiramp_down = _init(model, :eq_min_flexiramp_down)

    for sc in instance.scenarios
        haskey(sc, :flexiramp_reserves) || continue
        isempty(sc[:flexiramp_reserves]) && continue

        # Collect generators that participate in flexiramp reserves
        flexiramp_generators = ThermalUnit[]
        seen = Set{String}()
        for r in sc[:flexiramp_reserves]
            for g in r.thermal_units
                if g.name ∉ seen
                    push!(seen, g.name)
                    push!(flexiramp_generators, g)
                end
            end
        end

        # Create mfg variables (one per generator)
        for g in flexiramp_generators, t in 1:T
            mfg[sc.name, g.name, t] = @variable(model, lower_bound = 0)
        end

        # Create shortfall variables (one per reserve) and
        # flexiramp provision variables (one per reserve-generator pair)
        for r in sc[:flexiramp_reserves]
            for t in 1:T
                upflexiramp_shortfall[sc.name, r.name, t] =
                    @variable(model, lower_bound = 0)
                dwflexiramp_shortfall[sc.name, r.name, t] =
                    @variable(model, lower_bound = 0)
                if r.shortfall_penalty < 0
                    set_upper_bound(
                        upflexiramp_shortfall[sc.name, r.name, t],
                        0.0,
                    )
                    set_upper_bound(
                        dwflexiramp_shortfall[sc.name, r.name, t],
                        0.0,
                    )
                end
                for g in r.thermal_units
                    upflexiramp[sc.name, r.name, g.name, t] = @variable(model)
                    dwflexiramp[sc.name, r.name, g.name, t] = @variable(model)
                end
            end
        end

        # Generator-level constraints (Eq. 19, 22-25)
        for g in flexiramp_generators
            is_initially_on = (g.initial_status > 0)
            SU = g.startup_limit
            SD = g.shutdown_limit
            RU = g.ramp_up_limit
            RD = g.ramp_down_limit
            gn = g.name
            minp = g.min_power
            maxp = g.max_power
            initial_power = g.initial_power

            for t in 1:T
                # Eq. (19): prod_above + is_on*minp <= mfg
                eq_mfg_lb[sc.name, gn, t] = @constraint(
                    model,
                    prod_above[sc.name, gn, t] + (is_on[gn, t] * minp[t]) <=
                    mfg[sc.name, gn, t]
                )

                # Eq. (22): mfg <= is_on*maxp
                eq_mfg_ub[sc.name, gn, t] = @constraint(
                    model,
                    mfg[sc.name, gn, t] <= is_on[gn, t] * maxp[t]
                )

                # Eq. (23): ramp up
                if t == 1
                    eq_ramp_up[sc.name, gn, t] = @constraint(
                        model,
                        mfg[sc.name, gn, t] <=
                        initial_power +
                        (RU * is_initially_on) +
                        (SU * (is_on[gn, t] - is_initially_on)) +
                        maxp[t] * (1 - is_on[gn, t])
                    )
                else
                    eq_ramp_up[sc.name, gn, t] = @constraint(
                        model,
                        mfg[sc.name, gn, t] <=
                        prod_above[sc.name, gn, t-1] +
                        (is_on[gn, t-1] * minp[t]) +
                        (RU * is_on[gn, t-1]) +
                        (SU * (is_on[gn, t] - is_on[gn, t-1])) +
                        maxp[t] * (1 - is_on[gn, t])
                    )
                end

                # Eq. (25): ramp down
                if t == 1
                    eq_ramp_down[sc.name, gn, t] = @constraint(
                        model,
                        initial_power - (
                            prod_above[sc.name, gn, t] +
                            (is_on[gn, t] * minp[t])
                        ) <=
                        RD * is_on[gn, t] +
                        SD * (is_initially_on - is_on[gn, t]) +
                        maxp[t] * (1 - is_initially_on)
                    )
                else
                    eq_ramp_down[sc.name, gn, t] = @constraint(
                        model,
                        (
                            prod_above[sc.name, gn, t-1] +
                            (is_on[gn, t-1] * minp[t])
                        ) - (
                            prod_above[sc.name, gn, t] +
                            (is_on[gn, t] * minp[t])
                        ) <=
                        RD * is_on[gn, t] +
                        SD * (is_on[gn, t-1] - is_on[gn, t]) +
                        maxp[t] * (1 - is_on[gn, t-1])
                    )
                end
            end

            # Constraints for t in 1:T-1 (require t+1)
            for t in 1:(T-1)
                # Eq. (24): mfg shutdown
                eq_mfg_shutdown[sc.name, gn, t] = @constraint(
                    model,
                    mfg[sc.name, gn, t] <=
                    (SD * (is_on[gn, t] - is_on[gn, t+1])) +
                    (maxp[t] * is_on[gn, t+1])
                )
            end
        end

        # Reserve-generator constraints (Eq. 20-21, 26-29)
        for r in sc[:flexiramp_reserves]
            rn = r.name
            for g in r.thermal_units
                gn = g.name
                SU = g.startup_limit
                SD = g.shutdown_limit
                RU = g.ramp_up_limit
                RD = g.ramp_down_limit
                minp = g.min_power
                maxp = g.max_power

                for t in 1:(T-1)
                    # Eq. (20) first: minp*(is_on[t+1]+is_on[t]-1) <= prod_above - dwflexi + is_on*minp
                    eq_dwflexi_lb[sc.name, rn, gn, t] = @constraint(
                        model,
                        minp[t] * (is_on[gn, t+1] + is_on[gn, t] - 1) <=
                        prod_above[sc.name, gn, t] -
                        dwflexiramp[sc.name, rn, gn, t] +
                        (is_on[gn, t] * minp[t])
                    )

                    # Eq. (20) second: prod_above - dwflexi + is_on*minp <= mfg[t+1] + maxp*(1-is_on[t+1])
                    eq_dwflexi_ub[sc.name, rn, gn, t] = @constraint(
                        model,
                        prod_above[sc.name, gn, t] -
                        dwflexiramp[sc.name, rn, gn, t] +
                        (is_on[gn, t] * minp[t]) <=
                        mfg[sc.name, gn, t+1] +
                        (maxp[t] * (1 - is_on[gn, t+1]))
                    )

                    # Eq. (21) first: minp*(is_on[t+1]+is_on[t]-1) <= prod_above + upflexi + is_on*minp
                    eq_upflexi_lb[sc.name, rn, gn, t] = @constraint(
                        model,
                        minp[t] * (is_on[gn, t+1] + is_on[gn, t] - 1) <=
                        prod_above[sc.name, gn, t] +
                        upflexiramp[sc.name, rn, gn, t] +
                        (is_on[gn, t] * minp[t])
                    )

                    # Eq. (21) second: prod_above + upflexi + is_on*minp <= mfg[t+1] + maxp*(1-is_on[t+1])
                    eq_upflexi_ub[sc.name, rn, gn, t] = @constraint(
                        model,
                        prod_above[sc.name, gn, t] +
                        upflexiramp[sc.name, rn, gn, t] +
                        (is_on[gn, t] * minp[t]) <=
                        mfg[sc.name, gn, t+1] +
                        (maxp[t] * (1 - is_on[gn, t+1]))
                    )

                    # Eq. (26) first: -RD*is_on[t+1] - SD*(is_on[t]-is_on[t+1]) - maxp*(1-is_on[t]) <= upflexi
                    eq_upflexi_ramp_lb[sc.name, rn, gn, t] = @constraint(
                        model,
                        -RD * is_on[gn, t+1] -
                        SD * (is_on[gn, t] - is_on[gn, t+1]) -
                        maxp[t] * (1 - is_on[gn, t]) <=
                        upflexiramp[sc.name, rn, gn, t]
                    )

                    # Eq. (26) second: upflexi <= RU*is_on[t] + SU*(is_on[t+1]-is_on[t]) + maxp*(1-is_on[t+1])
                    eq_upflexi_ramp_ub[sc.name, rn, gn, t] = @constraint(
                        model,
                        upflexiramp[sc.name, rn, gn, t] <=
                        RU * is_on[gn, t] +
                        SU * (is_on[gn, t+1] - is_on[gn, t]) +
                        maxp[t] * (1 - is_on[gn, t+1])
                    )

                    # Eq. (27) first: -RU*is_on[t] - SU*(is_on[t+1]-is_on[t]) - maxp*(1-is_on[t+1]) <= dwflexi
                    eq_dwflexi_ramp_lb[sc.name, rn, gn, t] = @constraint(
                        model,
                        -RU * is_on[gn, t] -
                        SU * (is_on[gn, t+1] - is_on[gn, t]) -
                        maxp[t] * (1 - is_on[gn, t+1]) <=
                        dwflexiramp[sc.name, rn, gn, t]
                    )

                    # Eq. (27) second: dwflexi <= RD*is_on[t+1] + SD*(is_on[t]-is_on[t+1]) + maxp*(1-is_on[t])
                    eq_dwflexi_ramp_ub[sc.name, rn, gn, t] = @constraint(
                        model,
                        dwflexiramp[sc.name, rn, gn, t] <=
                        RD * is_on[gn, t+1] +
                        SD * (is_on[gn, t] - is_on[gn, t+1]) +
                        maxp[t] * (1 - is_on[gn, t])
                    )

                    # Eq. (28) first: -maxp*is_on[t] + minp*is_on[t+1] <= upflexi
                    eq_upflexi_power_lb[sc.name, rn, gn, t] = @constraint(
                        model,
                        -maxp[t] * is_on[gn, t] + minp[t] * is_on[gn, t+1] <=
                        upflexiramp[sc.name, rn, gn, t]
                    )

                    # Eq. (28) second: upflexi <= maxp*is_on[t+1]
                    eq_upflexi_power_ub[sc.name, rn, gn, t] = @constraint(
                        model,
                        upflexiramp[sc.name, rn, gn, t] <=
                        maxp[t] * is_on[gn, t+1]
                    )

                    # Eq. (29) first: -maxp*is_on[t+1] <= dwflexi
                    eq_dwflexi_power_lb[sc.name, rn, gn, t] = @constraint(
                        model,
                        -maxp[t] * is_on[gn, t+1] <=
                        dwflexiramp[sc.name, rn, gn, t]
                    )

                    # Eq. (29) second: dwflexi <= maxp*is_on[t] - minp*is_on[t+1]
                    eq_dwflexi_power_ub[sc.name, rn, gn, t] = @constraint(
                        model,
                        dwflexiramp[sc.name, rn, gn, t] <=
                        (maxp[t] * is_on[gn, t]) - (minp[t] * is_on[gn, t+1])
                    )
                end
            end
        end

        # Requirement constraints and objective
        for r in sc[:flexiramp_reserves]
            rn = r.name
            for t in 1:T
                # Sum of up provisions + shortfall >= requirement
                eq_min_flexiramp_up[sc.name, rn, t] = @constraint(
                    model,
                    sum(
                        upflexiramp[sc.name, rn, g.name, t] for
                        g in r.thermal_units
                    ) + upflexiramp_shortfall[sc.name, rn, t] >=
                    r.amount[t]
                )

                # Sum of down provisions + shortfall >= requirement
                eq_min_flexiramp_down[sc.name, rn, t] = @constraint(
                    model,
                    sum(
                        dwflexiramp[sc.name, rn, g.name, t] for
                        g in r.thermal_units
                    ) + dwflexiramp_shortfall[sc.name, rn, t] >=
                    r.amount[t]
                )
            end

            # Shortfall penalty in objective
            if r.shortfall_penalty >= 0
                for t in 1:T
                    add_to_expression!(
                        model[:obj],
                        r.shortfall_penalty * sc[:probability],
                        upflexiramp_shortfall[sc.name, rn, t],
                    )
                    add_to_expression!(
                        model[:obj],
                        r.shortfall_penalty * sc[:probability],
                        dwflexiramp_shortfall[sc.name, rn, t],
                    )
                end
            end
        end
    end
    return
end
