# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

function _add_interface!(
    model::JuMP.Model,
    ifc::Interface,
    f::ShiftFactorsFormulation,
    sc::UnitCommitmentScenario,
)::Nothing
    overflow = _init(model, :interface_overflow)
    net_injection = _init(model, :net_injection)
    for t in 1:model[:instance].time
        # define the net flow variable
        flow = @variable(model, base_name = "interface_flow[$(ifc.name),$t]")
        # define the overflow variable 
        overflow[sc.name, ifc.name, t] = @variable(model, lower_bound = 0)
        # constraints: lb - v <= flow <= ub + v
        @constraint(
            model,
            flow <=
            ifc.net_flow_upper_limit[t] + overflow[sc.name, ifc.name, t]
        )
        @constraint(
            model,
            -flow <=
            -ifc.net_flow_lower_limit[t] + overflow[sc.name, ifc.name, t]
        )
        # constraint: flow value is calculated from the interface ISF matrix
        @constraint(
            model,
            flow == sum(
                net_injection[sc.name, b.name, t] *
                sc.interface_isf[ifc.offset, b.offset] for
                b in sc.buses if b.offset > 0
            )
        )
        # make overflow part of the objective as a punishment term
        add_to_expression!(
            model[:obj],
            overflow[sc.name, ifc.name, t],
            ifc.flow_limit_penalty[t] * sc.probability,
        )
    end
    return
end
