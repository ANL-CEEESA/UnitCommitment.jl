# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

function set_warm_start!(model::JuMP.Model, solution::AbstractDict)::Nothing
    instance, T = model[:instance], model[:instance].time
    is_on = model[:is_on]
    for g in instance.thermal_units
        for t in 1:T
            JuMP.set_start_value(is_on[g.name, t], solution["Is on"][g.name][t])
            JuMP.set_start_value(
                switch_on[g.name, t],
                solution["Switch on"][g.name][t],
            )
            JuMP.set_start_value(
                switch_off[g.name, t],
                solution["Switch off"][g.name][t],
            )
        end
    end
    return
end
