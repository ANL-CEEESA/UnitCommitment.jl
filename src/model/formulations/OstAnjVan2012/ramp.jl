# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

"""
    _add_ramp_eqs!

Ensure constraints on ramping are met.
Based on Ostrowski, Anjos, Vannelli (2012).
Eqn (37) in Kneuven et al. (2020).

Variables
---
* :is_on
* :prod_above
* :reserve

Constraints
---
* :eq_str_prod_limit
"""
function _add_ramp_eqs!(
    model::JuMP.Model,
    g::Unit,
    formulation_prod_vars::Gar1962.ProdVars,
    formulation_ramping::MorLatRam2013.Ramping,
    formulation_status_vars::Gar1962.StatusVars,
)::Nothing
    # TODO: Move upper case constants to model[:instance]
    RESERVES_WHEN_START_UP = true
    RESERVES_WHEN_RAMP_UP = true
    RESERVES_WHEN_RAMP_DOWN = true
    RESERVES_WHEN_SHUT_DOWN = true
    is_initially_on = _is_initially_on(g)

    gn = g.name
    eq_str_prod_limit = _init(model, :eq_str_prod_limit)

    # Variables that we need
    reserve = model[:reserve]

    # Gar1962.ProdVars
    prod_above = model[:prod_above]

    # Gar1962.StatusVars
    is_on = model[:is_on]
    switch_off = model[:switch_off]

    # The following are the same for generator g across all time periods
    UT = g.min_uptime

    SU = g.startup_limit   # startup rate
    SD = g.shutdown_limit  # shutdown rate
    RU = g.ramp_up_limit   # ramp up rate
    RD = g.ramp_down_limit # ramp down rate
    
    # TODO check initial conditions, but maybe okay as long as (35) and (36) are also used
    for t in 1:model[:instance].time
        Pbar = g.max_power[t]
    
        #TRD = floor((Pbar - SU)/RD)
        # TODO check amk changed TRD wrt Kneuven et al.
        TRD = ceil((Pbar - SD) / RD) # ramp down time

        if Pbar < 1e-7
          # Skip this time period if max power = 0
          continue
        end

        if UT >= 1
            # Equation (37) in Kneuven et al. (2020)
            KSD = min( TRD, UT-1, T-t-1 )
            eq_str_prod_limit[gn, t] =
            @constraint(model,
                        prod_above[gn, t] + g.min_power[t] * is_on[gn, t]
                        + (RESERVES_WHEN_RAMP_DOWN ? reserve[gn, t] : 0.) # amk added; TODO: should this be RESERVES_WHEN_RAMP_DOWN or RESERVES_WHEN_SHUT_DOWN?
                        <= Pbar * is_on[gi, t]
                            - sum((Pbar - (SD + i * RD)) * switch_off[gi, t+1+i]
                                for i in 0:KSD)
                        )
        end # check UT >= 1
    end # loop over time
end
