# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

function _bus_shunt_loss(sc::UnitCommitmentScenario, bus, t::Int)::Float64
    loss = 0.0
    for sh in sc[:shunts_by_bus][bus]
        if sh.status[t]
            loss += sh.conductance * sc[:base_mva]
        end
    end
    return loss
end

function _shunt_loss_matrix(sc::UnitCommitmentScenario, T::Int)
    buses = sc[:bus]
    n = count(b -> b.offset > 0, buses)
    sl = zeros(n, T)
    for b in buses
        b.offset > 0 || continue
        for t in 1:T
            sl[b.offset, t] = _bus_shunt_loss(sc, b, t)
        end
    end
    return sl
end
