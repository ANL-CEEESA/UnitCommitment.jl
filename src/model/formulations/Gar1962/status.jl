# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

"""
    _add_status_vars!

Adds symbols identified by `Gar1962.StatusVars` to `model`.
Fix variables if a certain generator _must_ run or based on initial conditions.
"""
function _add_status_vars!(
    model::JuMP.Model,
    g::Unit,
    formulation_status_vars::Gar1962.StatusVars,
)::Nothing
    is_on = _init(model, :is_on)
    switch_on = _init(model, :switch_on)
    switch_off = _init(model, :switch_off)
    FIX_VARS = !formulation_status_vars.fix_vars_via_constraint
    for t in 1:model[:instance].time
        is_on[g.name, t] = @variable(model, binary = true)
        switch_on[g.name, t] = @variable(model, binary = true)
        switch_off[g.name, t] = @variable(model, binary = true)

        # Use initial conditions and whether a unit must run to fix variables
        if FIX_VARS
            # Fix variables using fix function
            if g.must_run[t]
                # If the generator _must_ run, then it is obviously on and cannot be switched off
                # In the first time period, force unit to switch on if was off before
                # Otherwise, unit is on, and will never turn off, so will never need to turn on
                fix(is_on[g.name, t], 1.0; force = true)
                fix(
                    switch_on[g.name, t],
                    (t == 1 ? 1.0 - _is_initially_on(g) : 0.0);
                    force = true,
                )
                fix(switch_off[g.name, t], 0.0; force = true)
            elseif t == 1
                if _is_initially_on(g)
                    # Generator was on (for g.initial_status time periods),
                    # so cannot be more switched on until the period after the first time it can be turned off
                    fix(switch_on[g.name, 1], 0.0; force = true)
                else
                    # Generator is initially off (for -g.initial_status time periods)
                    # Cannot be switched off more
                    fix(switch_off[g.name, 1], 0.0; force = true)
                end
            end
        else
            # Add explicit constraint if !FIX_VARS
            if g.must_run[t]
                is_on[g.name, t] = 1.0
                switch_on[g.name, t] =
                    (t == 1 ? 1.0 - _is_initially_on(g) : 0.0)
                switch_off[g.name, t] = 0.0
            elseif t == 1
                if _is_initially_on(g)
                    switch_on[g.name, t] = 0.0
                else
                    switch_off[g.name, t] = 0.0
                end
            end
        end
    end
    return
end

"""
    _add_status_eqs!

Creates constraints `eq_binary_link` and `eq_switch_on_off` using variables in `Gar1962.StatusVars`.

Constraints
---
* `eq_binary_link`
* `eq_switch_on_off`
"""
function _add_status_eqs!(
    model::JuMP.Model,
    g::Unit,
    formulation_status_vars::Gar1962.StatusVars,
)::Nothing
    eq_binary_link = _init(model, :eq_binary_link)
    eq_switch_on_off = _init(model, :eq_switch_on_off)
    is_on = model[:is_on]
    switch_off = model[:switch_off]
    switch_on = model[:switch_on]
    for t in 1:model[:instance].time
        if g.must_run[t]
            continue
        end

        # Link binary variables
        # Equation (2) in Knueven et al. (2020), originally from Garver (1962)
        if t == 1
            eq_binary_link[g.name, t] = @constraint(
                model,
                is_on[g.name, t] - _is_initially_on(g) ==
                switch_on[g.name, t] - switch_off[g.name, t]
            )
        else
            eq_binary_link[g.name, t] = @constraint(
                model,
                is_on[g.name, t] - is_on[g.name, t-1] ==
                switch_on[g.name, t] - switch_off[g.name, t]
            )
        end

        # Cannot switch on and off at the same time
        # amk: I am not sure this is in Knueven et al. (2020)
        eq_switch_on_off[g.name, t] = @constraint(
            model,
            switch_on[g.name, t] + switch_off[g.name, t] <= 1
        )
    end
    return
end
