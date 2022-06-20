# UnitCommitmentFL.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

function _add_ramp_eqs!(
    model::JuMP.Model,
    g::Unit,
    ::Gar1962.ProdVars,
    ::WanHob2016.Ramping,
    ::Gar1962.StatusVars,
)::Nothing
    is_initially_on = (g.initial_status > 0)
    SU = g.startup_limit
    SD = g.shutdown_limit
    RU = g.ramp_up_limit
    RD = g.ramp_down_limit
    gn = g.name
    minp = g.min_power
    maxp = g.max_power
    initial_power = g.initial_power

    is_on = model[:is_on]
    prod_above = model[:prod_above]
    upflexiramp = model[:upflexiramp]
    dwflexiramp = model[:dwflexiramp]
    mfg = model[:mfg]

    if length(g.reserves) > 1
        error("Each generator may only provide one flexiramp reserve")
    end
    for r in g.reserves
        if r.type !== "flexiramp"
            error("This formulation only supports flexiramp reserves, not $(r.type)")
        end
        rn = r.name
        for t in 1:model[:instance].time
            @constraint(
                model,
                prod_above[gn, t] + (is_on[gn, t] * minp[t]) <= mfg[rn, gn, t]
            ) # Eq. (19) in Wang & Hobbs (2016)
            @constraint(model, mfg[rn, gn, t] <= is_on[gn, t] * maxp[t]) # Eq. (22) in Wang & Hobbs (2016)
            if t != model[:instance].time
                @constraint(
                    model,
                    minp[t] * (is_on[gn, t+1] + is_on[gn, t] - 1) <=
                    prod_above[gn, t] - dwflexiramp[rn, gn, t] +
                    (is_on[gn, t] * minp[t])
                ) # first inequality of Eq. (20) in Wang & Hobbs (2016)
                @constraint(
                    model,
                    prod_above[gn, t] - dwflexiramp[rn, gn, t] +
                    (is_on[gn, t] * minp[t]) <=
                    mfg[rn, gn, t+1] + (maxp[t] * (1 - is_on[gn, t+1]))
                ) # second inequality of Eq. (20) in Wang & Hobbs (2016)
                @constraint(
                    model,
                    minp[t] * (is_on[gn, t+1] + is_on[gn, t] - 1) <=
                    prod_above[gn, t] +
                    upflexiramp[rn, gn, t] +
                    (is_on[gn, t] * minp[t])
                ) # first inequality of Eq. (21) in Wang & Hobbs (2016)
                @constraint(
                    model,
                    prod_above[gn, t] +
                    upflexiramp[rn, gn, t] +
                    (is_on[gn, t] * minp[t]) <=
                    mfg[rn, gn, t+1] + (maxp[t] * (1 - is_on[gn, t+1]))
                ) # second inequality of Eq. (21) in Wang & Hobbs (2016)
                if t != 1
                    @constraint(
                        model,
                        mfg[rn, gn, t] <=
                        prod_above[gn, t-1] +
                        (is_on[gn, t-1] * minp[t]) +
                        (RU * is_on[gn, t-1]) +
                        (SU * (is_on[gn, t] - is_on[gn, t-1])) +
                        maxp[t] * (1 - is_on[gn, t])
                    ) # Eq. (23) in Wang & Hobbs (2016)
                    @constraint(
                        model,
                        (prod_above[gn, t-1] + (is_on[gn, t-1] * minp[t])) -
                        (prod_above[gn, t] + (is_on[gn, t] * minp[t])) <=
                        RD * is_on[gn, t] +
                        SD * (is_on[gn, t-1] - is_on[gn, t]) +
                        maxp[t] * (1 - is_on[gn, t-1])
                    ) # Eq. (25) in Wang & Hobbs (2016)
                else
                    @constraint(
                        model,
                        mfg[rn, gn, t] <=
                        initial_power +
                        (RU * is_initially_on) +
                        (SU * (is_on[gn, t] - is_initially_on)) +
                        maxp[t] * (1 - is_on[gn, t])
                    ) # Eq. (23) in Wang & Hobbs (2016) for the first time period
                    @constraint(
                        model,
                        initial_power -
                        (prod_above[gn, t] + (is_on[gn, t] * minp[t])) <=
                        RD * is_on[gn, t] +
                        SD * (is_initially_on - is_on[gn, t]) +
                        maxp[t] * (1 - is_initially_on)
                    ) # Eq. (25) in Wang & Hobbs (2016) for the first time period
                end
                @constraint(
                    model,
                    mfg[rn, gn, t] <=
                    (SD * (is_on[gn, t] - is_on[gn, t+1])) +
                    (maxp[t] * is_on[gn, t+1])
                ) # Eq. (24) in Wang & Hobbs (2016)
                @constraint(
                    model,
                    -RD * is_on[gn, t+1] - SD * (is_on[gn, t] - is_on[gn, t+1]) -
                    maxp[t] * (1 - is_on[gn, t]) <= upflexiramp[rn, gn, t]
                ) # first inequality of Eq. (26) in Wang & Hobbs (2016)
                @constraint(
                    model,
                    upflexiramp[rn, gn, t] <=
                    RU * is_on[gn, t] +
                    SU * (is_on[gn, t+1] - is_on[gn, t]) +
                    maxp[t] * (1 - is_on[gn, t+1])
                ) # second inequality of Eq. (26) in Wang & Hobbs (2016)
                @constraint(
                    model,
                    -RU * is_on[gn, t] - SU * (is_on[gn, t+1] - is_on[gn, t]) -
                    maxp[t] * (1 - is_on[gn, t+1]) <= dwflexiramp[rn, gn, t]
                ) # first inequality of Eq. (27) in Wang & Hobbs (2016)
                @constraint(
                    model,
                    dwflexiramp[rn, gn, t] <=
                    RD * is_on[gn, t+1] +
                    SD * (is_on[gn, t] - is_on[gn, t+1]) +
                    maxp[t] * (1 - is_on[gn, t])
                ) # second inequality of Eq. (27) in Wang & Hobbs (2016)
                @constraint(
                    model,
                    -maxp[t] * is_on[gn, t] + minp[t] * is_on[gn, t+1] <=
                    upflexiramp[rn, gn, t]
                ) # first inequality of Eq. (28) in Wang & Hobbs (2016)
                @constraint(model, upflexiramp[rn, gn, t] <= maxp[t] * is_on[gn, t+1]) # second inequality of Eq. (28) in Wang & Hobbs (2016)
                @constraint(model, -maxp[t] * is_on[gn, t+1] <= dwflexiramp[rn, gn, t]) # first inequality of Eq. (29) in Wang & Hobbs (2016)
                @constraint(
                    model,
                    dwflexiramp[rn, gn, t] <=
                    (maxp[t] * is_on[gn, t]) - (minp[t] * is_on[gn, t+1])
                ) # second inequality of Eq. (29) in Wang & Hobbs (2016)
            else
                @constraint(
                    model,
                    mfg[rn, gn, t] <=
                    prod_above[gn, t-1] +
                    (is_on[gn, t-1] * minp[t]) +
                    (RU * is_on[gn, t-1]) +
                    (SU * (is_on[gn, t] - is_on[gn, t-1])) +
                    maxp[t] * (1 - is_on[gn, t])
                ) # Eq. (23) in Wang & Hobbs (2016) for the last time period
                @constraint(
                    model,
                    (prod_above[gn, t-1] + (is_on[gn, t-1] * minp[t])) -
                    (prod_above[gn, t] + (is_on[gn, t] * minp[t])) <=
                    RD * is_on[gn, t] +
                    SD * (is_on[gn, t-1] - is_on[gn, t]) +
                    maxp[t] * (1 - is_on[gn, t-1])
                ) # Eq. (25) in Wang & Hobbs (2016) for the last time period
            end
        end
    end
end
