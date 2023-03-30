# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

function _add_status_vars!(
    model::JuMP.Model,
    g::Unit,
    formulation_status_vars::Gar1962.StatusVars,
)::Nothing
    is_on = _init(model, :is_on)
    switch_on = _init(model, :switch_on)
    switch_off = _init(model, :switch_off)
    for t in 1:model[:instance].time
        if g.must_run[t]
            is_on[g.name, t] = 1.0
            switch_on[g.name, t] = (t == 1 ? 1.0 - _is_initially_on(g) : 0.0)
            switch_off[g.name, t] = 0.0
        else
            is_on[g.name, t] = @variable(model, binary = true)
            switch_on[g.name, t] = @variable(model, binary = true)
            switch_off[g.name, t] = @variable(model, binary = true)
        end
        add_to_expression!(model[:obj], is_on[g.name, t], g.min_power_cost[t])
    end
    return
end

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
        if !g.must_run[t]
            # Link binary variables
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
            eq_switch_on_off[g.name, t] = @constraint(
                model,
                switch_on[g.name, t] + switch_off[g.name, t] <= 1
            )
        end
    end
    return
end
