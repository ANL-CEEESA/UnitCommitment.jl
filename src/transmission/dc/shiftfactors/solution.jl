# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

function _compute_base_flow(
    model::UnitCommitmentModel,
    sc::UnitCommitmentScenario,
    ::ShiftFactorsTransmissionExt,
)
    T = model.instance.time
    branches = sc[:branches]
    if isempty(branches)
        return zeros(0, T)
    end
    buses = sc[:bus]
    ni = model.inner[:ni]
    isf = sc[:isf]

    non_slack = [b for b in buses if b.offset > 0]
    net_inj = [value(ni[sc.name, b.name, t]) for b in non_slack, t in 1:T]
    shunt_loss = _shunt_loss_matrix(sc, T)
    return isf * (net_inj - shunt_loss)
end

function _compute_contingency_flow(
    model::UnitCommitmentModel,
    sc::UnitCommitmentScenario,
    pre_flow::Array{Float64,2},
    ::ShiftFactorsTransmissionExt,
)
    lodf = sc[:lodf]
    contingencies = sc[:contingencies]
    L = size(pre_flow, 1)
    T = size(pre_flow, 2)

    vulnerable =
        collect(Set{Int}(lc.offset for c in contingencies for lc in c.branches))

    post_flow = Dict{Int,Array{Float64,2}}()
    for lc in vulnerable
        @views post_flow[lc] = pre_flow .+ lodf[:, lc] * pre_flow[lc:lc, :]
    end

    return post_flow
end

function _compute_interface_flows(
    model::UnitCommitmentModel,
    sc::UnitCommitmentScenario,
    T::Int,
    ::ShiftFactorsTransmissionExt,
)
    inner = model.inner
    interfaces = sc[:interfaces]
    I = length(interfaces)
    isempty(interfaces) && return zeros(0, T)

    ifc_isf = sc[:interface_isf]
    buses = sc[:bus]
    non_slack = [b for b in buses if b.offset > 0]
    net_inj =
        [value(inner[:ni][sc.name, b.name, t]) for b in non_slack, t in 1:T]
    shunt_loss = _shunt_loss_matrix(sc, T)
    return ifc_isf * (net_inj - shunt_loss)
end
