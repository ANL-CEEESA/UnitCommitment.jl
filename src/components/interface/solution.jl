# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

function store_solution(
    sol::AbstractDict,
    model::UnitCommitmentModel,
    ::InterfaceLimitsExt,
)::Nothing
    instance = model.instance
    inner = model.inner
    T = instance.time
    transmission_ext = instance.extension_by_slot[:transmission]

    for sc in instance.scenarios
        interfaces = sc[:interfaces]
        isempty(interfaces) && continue

        # Compute interface flows via dispatch
        flow_values = _compute_interface_flows(model, sc, T, transmission_ext)

        sol[sc.name]["Interface: Flow (MW)"] = OrderedDict(
            ifc.name => [
                round(flow_values[ifc.offset, t], digits = 5) for t in 1:T
            ] for ifc in interfaces
        )

        sol[sc.name]["Interface: Overflow (MW)"] =
            _timeseries(inner, :interface_overflow, interfaces, T, sc = sc)

        sol[sc.name]["Interface: Overflow penalty (\$)"] = OrderedDict(
            ifc.name => [
                round(
                    value(inner[:interface_overflow][sc.name, ifc.name, t]) * ifc.flow_limit_penalty[t],
                    digits = 5,
                ) for t in 1:T
            ] for ifc in interfaces
        )
    end
    return nothing
end
