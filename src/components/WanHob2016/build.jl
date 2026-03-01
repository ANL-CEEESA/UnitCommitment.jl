# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

# Formulation described in:
#
#     B. Wang and B. F. Hobbs, "Real-Time Markets for Flexiramp: A Stochastic
#     Unit Commitment-Based Analysis," in IEEE Transactions on Power Systems,
#     vol. 31, no. 2, pp. 846-860, March 2016, doi: 10.1109/TPWRS.2015.2411268.
#
# Paper notation → code mapping:
#   g_{its}    generation                 = prod_above[t] + is_on[t] * minp[t]
#   ḡ_{its}    max feasible generation    = mfg[t]
#   v_{its}    commitment (on/off)        = is_on[t]
#   ur_{its}   up-flexiramp provision     = upflexiramp[t]
#   dr_{its}   down-flexiramp provision   = dwflexiramp[t]
#   Cap_i      capacity (max power)       = maxp[t]
#   _Cap_i     minimum output             = minp[t]
#   RR_i       ramp rate                  → RU (up) / RD (down)
#   SURR_i     startup ramp limit         = SU
#   SDRR_i     shutdown ramp limit        = SD
#   FRup_t     up-flexiramp requirement   = r.amount[t]
#   FRdn_t     down-flexiramp requirement = r.amount[t]

function build_model(
    model::JuMP.Model,
    instance::UnitCommitmentInstance,
    ::WanHob2016.FlexirampExt,
)::Nothing
    T = instance.time

    mfg = _init(model, :mfg)
    upflexiramp = _init(model, :upflexiramp)
    dwflexiramp = _init(model, :dwflexiramp)
    upflexiramp_shortfall = _init(model, :upflexiramp_shortfall)
    dwflexiramp_shortfall = _init(model, :dwflexiramp_shortfall)

    is_on = model[:is_on]
    prod_above = model[:prod_above]

    eq_min_flexiramp_up = _init(model, :eq_min_flexiramp_up)
    eq_min_flexiramp_down = _init(model, :eq_min_flexiramp_down)
    eq_mfg_lb = _init(model, :eq_mfg_lb)
    eq_dwflexi_lb = _init(model, :eq_dwflexi_lb)
    eq_dwflexi_ub = _init(model, :eq_dwflexi_ub)
    eq_upflexi_lb = _init(model, :eq_upflexi_lb)
    eq_upflexi_ub = _init(model, :eq_upflexi_ub)
    eq_mfg_ub = _init(model, :eq_mfg_ub)
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

        # Validate: formulation assumes time-invariant min_power
        # (uses minp[t] for adjacent periods t-1 and t+1)
        for g in flexiramp_generators
            allequal(g.min_power) || error(
                "WanHob2016.FlexirampExt requires constant min_power, " *
                "but generator $(g.name) has time-varying min_power",
            )
        end

        # =====================================================================
        # Decision variables
        # =====================================================================

        # ḡ_{its}: max feasible generation (one per generator, all t)
        for g in flexiramp_generators, t in 1:T
            mfg[sc.name, g.name, t] = @variable(model, lower_bound = 0)
        end

        # ur_{its}, dr_{its}: flexiramp provision (one per reserve-generator pair).
        # Shortfall variables (one per reserve).
        # Paper omits these at the last interval (no t+1 exists).
        for r in sc[:flexiramp_reserves]
            for t in 1:(T-1)
                if r.shortfall_penalty < 0
                    upflexiramp_shortfall[sc.name, r.name, t] = 0.0
                    dwflexiramp_shortfall[sc.name, r.name, t] = 0.0
                else
                    upflexiramp_shortfall[sc.name, r.name, t] =
                        @variable(model, lower_bound = 0)
                    dwflexiramp_shortfall[sc.name, r.name, t] =
                        @variable(model, lower_bound = 0)
                end
                for g in r.thermal_units
                    upflexiramp[sc.name, r.name, g.name, t] = @variable(model)
                    dwflexiramp[sc.name, r.name, g.name, t] = @variable(model)
                end
            end
        end

        # =====================================================================
        # Objective terms
        # =====================================================================

        for r in sc[:flexiramp_reserves]
            if r.shortfall_penalty >= 0
                for t in 1:(T-1)
                    add_to_expression!(
                        model[:obj],
                        r.shortfall_penalty * sc[:probability],
                        upflexiramp_shortfall[sc.name, r.name, t],
                    )
                    add_to_expression!(
                        model[:obj],
                        r.shortfall_penalty * sc[:probability],
                        dwflexiramp_shortfall[sc.name, r.name, t],
                    )
                end
            end
        end

        # =====================================================================
        # Constraints (Eq. 17-29)
        # =====================================================================

        # Eq. 17-18: Flexiramp market clearing
        for r in sc[:flexiramp_reserves]
            rn = r.name
            for t in 1:(T-1)
                # Eq. (17): Σ_i ur_it ≥ FRup_t — total up-flexiramp must meet requirement
                eq_min_flexiramp_up[sc.name, rn, t] = @constraint(
                    model,
                    sum(
                        upflexiramp[sc.name, rn, g.name, t] for
                        g in r.thermal_units
                    ) + upflexiramp_shortfall[sc.name, rn, t] >=
                    r.amount[t]
                )

                # Eq. (18): Σ_i dr_it ≥ FRdn_t — total down-flexiramp must meet requirement
                eq_min_flexiramp_down[sc.name, rn, t] = @constraint(
                    model,
                    sum(
                        dwflexiramp[sc.name, rn, g.name, t] for
                        g in r.thermal_units
                    ) + dwflexiramp_shortfall[sc.name, rn, t] >=
                    r.amount[t]
                )
            end
        end

        # Eq. 19: Generation bounds
        for g in flexiramp_generators
            gn = g.name
            minp = g.min_power
            for t in 1:T
                # Eq. (19): g_it ≤ ḡ_it — generation cannot exceed max feasible generation
                eq_mfg_lb[sc.name, gn, t] = @constraint(
                    model,
                    prod_above[sc.name, gn, t] + (is_on[gn, t] * minp[t]) <=
                    mfg[sc.name, gn, t]
                )
            end
        end

        # Eq. 20-21: Generation + flexiramp bounds
        for r in sc[:flexiramp_reserves]
            rn = r.name
            for g in r.thermal_units
                gn = g.name
                minp = g.min_power
                maxp = g.max_power
                for t in 1:(T-1)
                    # Eq. (20): _Cap·(v_{i(t+1)} + v_it - 1) ≤ g_it - dr_it ≤ ḡ_{i(t+1)} + Cap·(1 - v_{i(t+1)})
                    # Generation minus down-flexiramp must be feasible for the next interval.
                    eq_dwflexi_lb[sc.name, rn, gn, t] = @constraint(
                        model,
                        minp[t] * (is_on[gn, t+1] + is_on[gn, t] - 1) <=
                        prod_above[sc.name, gn, t] -
                        dwflexiramp[sc.name, rn, gn, t] +
                        (is_on[gn, t] * minp[t])
                    )

                    # Eq. (20) upper half
                    eq_dwflexi_ub[sc.name, rn, gn, t] = @constraint(
                        model,
                        prod_above[sc.name, gn, t] -
                        dwflexiramp[sc.name, rn, gn, t] +
                        (is_on[gn, t] * minp[t]) <=
                        mfg[sc.name, gn, t+1] +
                        (maxp[t] * (1 - is_on[gn, t+1]))
                    )

                    # Eq. (21): _Cap·(v_{i(t+1)} + v_it - 1) ≤ g_it + ur_it ≤ ḡ_{i(t+1)} + Cap·(1 - v_{i(t+1)})
                    # Generation plus up-flexiramp must be feasible for the next interval.
                    eq_upflexi_lb[sc.name, rn, gn, t] = @constraint(
                        model,
                        minp[t] * (is_on[gn, t+1] + is_on[gn, t] - 1) <=
                        prod_above[sc.name, gn, t] +
                        upflexiramp[sc.name, rn, gn, t] +
                        (is_on[gn, t] * minp[t])
                    )

                    # Eq. (21) upper half
                    eq_upflexi_ub[sc.name, rn, gn, t] = @constraint(
                        model,
                        prod_above[sc.name, gn, t] +
                        upflexiramp[sc.name, rn, gn, t] +
                        (is_on[gn, t] * minp[t]) <=
                        mfg[sc.name, gn, t+1] +
                        (maxp[t] * (1 - is_on[gn, t+1]))
                    )
                end
            end
        end

        # Eq. 22-25: Max feasible generation and ramp limits
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
                # Eq. (22): ḡ_it ≤ Cap_i · v_it — max feasible generation bounded by capacity
                eq_mfg_ub[sc.name, gn, t] = @constraint(
                    model,
                    mfg[sc.name, gn, t] <= is_on[gn, t] * maxp[t]
                )

                # Eq. (23): ḡ_it ≤ g_{i(t-1)} + RR·v_{i(t-1)} + SURR·(v_it - v_{i(t-1)}) + Cap_i·(1 - v_it)
                # Max feasible generation limited by ramp-up rate and startup ramp limit.
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

                # Eq. (24): ḡ_it ≤ SDRR·(v_it - v_{i(t+1)}) + Cap_i·v_{i(t+1)}
                # Max feasible generation limited by shutdown ramp limit.
                if t < T
                    eq_mfg_shutdown[sc.name, gn, t] = @constraint(
                        model,
                        mfg[sc.name, gn, t] <=
                        (SD * (is_on[gn, t] - is_on[gn, t+1])) +
                        (maxp[t] * is_on[gn, t+1])
                    )
                end

                # Eq. (25): g_{i(t-1)} - g_it ≤ RR·v_it + SDRR·(v_{i(t-1)} - v_it) + Cap_i·(1 - v_{i(t-1)})
                # Generation decrease limited by ramp-down rate and shutdown ramp limit.
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
        end

        # Eq. 26-29: Bounds on flexiramp
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
                    # Eq. (26): -RR·v_{i(t+1)} - SDRR·(v_it - v_{i(t+1)}) - Cap·(1 - v_it)
                    #           ≤ ur_it ≤ RR·v_it + SURR·(v_{i(t+1)} - v_it) + Cap·(1 - v_{i(t+1)})
                    # Up-flexiramp bounded by ramp rates accounting for startups and shutdowns.
                    eq_upflexi_ramp_lb[sc.name, rn, gn, t] = @constraint(
                        model,
                        -RD * is_on[gn, t+1] -
                        SD * (is_on[gn, t] - is_on[gn, t+1]) -
                        maxp[t] * (1 - is_on[gn, t]) <=
                        upflexiramp[sc.name, rn, gn, t]
                    )

                    # Eq. (26) upper half
                    eq_upflexi_ramp_ub[sc.name, rn, gn, t] = @constraint(
                        model,
                        upflexiramp[sc.name, rn, gn, t] <=
                        RU * is_on[gn, t] +
                        SU * (is_on[gn, t+1] - is_on[gn, t]) +
                        maxp[t] * (1 - is_on[gn, t+1])
                    )

                    # Eq. (27): -RR·v_it - SURR·(v_{i(t+1)} - v_it) - Cap·(1 - v_{i(t+1)})
                    #           ≤ dr_it ≤ RR·v_{i(t+1)} + SDRR·(v_it - v_{i(t+1)}) + Cap·(1 - v_it)
                    # Down-flexiramp bounded by ramp rates accounting for startups and shutdowns.
                    eq_dwflexi_ramp_lb[sc.name, rn, gn, t] = @constraint(
                        model,
                        -RU * is_on[gn, t] -
                        SU * (is_on[gn, t+1] - is_on[gn, t]) -
                        maxp[t] * (1 - is_on[gn, t+1]) <=
                        dwflexiramp[sc.name, rn, gn, t]
                    )

                    # Eq. (27) upper half
                    eq_dwflexi_ramp_ub[sc.name, rn, gn, t] = @constraint(
                        model,
                        dwflexiramp[sc.name, rn, gn, t] <=
                        RD * is_on[gn, t+1] +
                        SD * (is_on[gn, t] - is_on[gn, t+1]) +
                        maxp[t] * (1 - is_on[gn, t])
                    )

                    # Eq. (28): -Cap·v_it + _Cap·v_{i(t+1)} ≤ ur_it ≤ Cap·v_{i(t+1)}
                    # Up-flexiramp bounded by generation capacity limits.
                    eq_upflexi_power_lb[sc.name, rn, gn, t] = @constraint(
                        model,
                        -maxp[t] * is_on[gn, t] + minp[t] * is_on[gn, t+1] <=
                        upflexiramp[sc.name, rn, gn, t]
                    )

                    # Eq. (28) upper half
                    eq_upflexi_power_ub[sc.name, rn, gn, t] = @constraint(
                        model,
                        upflexiramp[sc.name, rn, gn, t] <=
                        maxp[t] * is_on[gn, t+1]
                    )

                    # Eq. (29): -Cap·v_{i(t+1)} ≤ dr_it ≤ Cap·v_it - _Cap·v_{i(t+1)}
                    # Down-flexiramp bounded by generation capacity limits.
                    eq_dwflexi_power_lb[sc.name, rn, gn, t] = @constraint(
                        model,
                        -maxp[t] * is_on[gn, t+1] <=
                        dwflexiramp[sc.name, rn, gn, t]
                    )

                    # Eq. (29) upper half
                    eq_dwflexi_power_ub[sc.name, rn, gn, t] = @constraint(
                        model,
                        dwflexiramp[sc.name, rn, gn, t] <=
                        (maxp[t] * is_on[gn, t]) - (minp[t] * is_on[gn, t+1])
                    )
                end
            end
        end
    end
    return
end
