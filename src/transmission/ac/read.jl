# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

function read_json(
    json::AbstractDict,
    sc::UnitCommitmentScenario,
    ::ACTransmissionExt,
)
    T = sc[:time]
    branches = ACBranch[]

    # Read AC branches from transmission lines
    if "Transmission lines" in keys(json)
        for (line_name, dict) in json["Transmission lines"]
            tap = to_scalar(dict["Tap ratio (p.u.)"], default = 1.0)
            is_transformer = to_scalar(dict["Transformer"], default = false)
            if !is_transformer && tap != 1.0
                is_transformer = true
            end
            branch = ACBranch(
                name = line_name,
                offset = length(branches) + 1,
                source = sc[:bus_by_name][dict["Source bus"]],
                target = sc[:bus_by_name][dict["Target bus"]],
                resistance = to_scalar(
                    dict["Resistance (p.u.)"],
                    default = 0.0,
                ),
                reactance = to_scalar(dict["Reactance (p.u.)"]),
                shunt_conductance = to_scalar(
                    dict["Shunt conductance (p.u.)"],
                    default = 0.0,
                ),
                shunt_susceptance = to_scalar(
                    dict["Shunt susceptance (p.u.)"],
                    default = 0.0,
                ),
                tap_ratio = tap,
                phase_shift = to_scalar(
                    dict["Phase shift (rad)"],
                    default = 0.0,
                ),
                is_transformer = is_transformer,
                normal_flow_limit = to_timeseries(
                    dict["Normal flow limit (MVA)"],
                    T,
                    default = [1e8 for t in 1:T],
                ),
                emergency_flow_limit = to_timeseries(
                    dict["Emergency flow limit (MVA)"],
                    T,
                    default = [1e8 for t in 1:T],
                ),
                flow_limit_penalty = to_timeseries(
                    dict["Flow limit penalty (\$/MW)"],
                    T,
                    default = [5000.0 for t in 1:T],
                ),
                angle_diff_min = to_scalar(
                    dict["Angle difference min (rad)"],
                    default = -π / 6,
                ),
                angle_diff_max = to_scalar(
                    dict["Angle difference max (rad)"],
                    default = π / 6,
                ),
            )
            push!(branches, branch)
        end
    end

    sc[:ac_branches] = branches
    sc[:ac_branch_by_name] = Dict(b.name => b for b in branches)

    # Read shunt devices
    shunts = ShuntDevice[]
    if "Shunt devices" in keys(json)
        for (shunt_name, dict) in json["Shunt devices"]
            shunt = ShuntDevice(
                name = shunt_name,
                bus = sc[:bus_by_name][dict["Bus"]],
                conductance = to_scalar(
                    dict["Conductance (p.u.)"],
                    default = 0.0,
                ),
                susceptance = to_scalar(
                    dict["Susceptance (p.u.)"],
                    default = 0.0,
                ),
                status = to_timeseries(
                    dict["Status"],
                    T,
                    default = [true for t in 1:T],
                ),
            )
            push!(shunts, shunt)
        end
    end

    sc[:shunts] = shunts

    return
end
