# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using JuMP

function _after_optimize!(
    model::JuMP.Model,
    ::ConventionalLMP,
)::Nothing
    # Record binary variables and their optimal values
    binary_vars = [(v, value(v)) for v in all_variables(model) if is_binary(v)]

    # Fix binary variables and remove binary constraint
    for (v, val) in binary_vars
        unset_binary(v)
        fix(v, val)
    end

    # Relax any remaining integer variables
    undo_relax = relax_integrality(model)

    # Solve LP and extract duals
    JuMP.optimize!(model)

    model.ext[:lmp_values] = OrderedDict()
    for (key, val) in model[:eq_net_injection]
        model.ext[:lmp_values][key] = dual(val)
    end

    # Restore model state
    undo_relax()
    for (v, _) in binary_vars
        unfix(v)
        set_binary(v)
    end
end

function _solution!(
    sol::AbstractDict,
    model::JuMP.Model,
    ::ConventionalLMP,
)::Nothing
    instance = model[:instance]
    T = instance.time
    for sc in instance.scenarios
        lmp = sol[sc.name]["Locational marginal price (\$/MWh)"] = Dict()
        for b in sc.buses, t in 1:T
            lmp[b.name, t] = model.ext[:lmp_values][sc.name, b.name, t]
        end
    end
    return
end
