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
            total_shunt_loss = sum(
                sh.conductance * sc[:base_mva] for
                sh in sc[:shunts] if sh.status[t];
                init = 0.0,
            )
            eq_power_balance[sc.name, t] = @constraint(
                model,
                sum(ni[sc.name, b.name, t] for b in sc[:bus]) ==
                total_shunt_loss,
            )
        end
    end
    return
end
