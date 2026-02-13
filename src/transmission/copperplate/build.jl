# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

function build_model(
    model::JuMP.Model,
    instance::UnitCommitmentInstance,
    ext::CopperPlateTransmissionExt,
)::Nothing
    eq_power_balance = _init(model, :eq_power_balance)
    for sc in instance.scenarios
        ni = model[:ni]
        for t in 1:instance.time
            eq_power_balance[sc.name, t] = @constraint(
                model,
                sum(ni[sc.name, b.name, t] for b in sc[:bus]) == 0,
            )
        end
    end
    return
end
