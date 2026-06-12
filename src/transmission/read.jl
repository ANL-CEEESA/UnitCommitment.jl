# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

function read_json(
    json::AbstractDict,
    sc::UnitCommitmentScenario,
    ::TransmissionExtension,
)
    T = sc[:time]
    branches = Branch[]

    # Read branches
    if "Branches" in keys(json)
        for (branch_name, dict) in json["Branches"]
            r = to_scalar(dict["Resistance (p.u.)"], default = 0.0)
            x = to_scalar(dict["Reactance (p.u.)"], default = 0.0)
            branch = Branch(
                name = branch_name,
                offset = length(branches) + 1,
                source = sc[:bus_by_name][dict["Source bus"]],
                target = sc[:bus_by_name][dict["Target bus"]],
                resistance = r,
                reactance = x,
                susceptance = x / (r^2 + x^2),
                shunt_conductance = to_scalar(
                    dict["Shunt conductance (p.u.)"],
                    default = 0.0,
                ),
                shunt_susceptance = to_scalar(
                    dict["Shunt susceptance (p.u.)"],
                    default = 0.0,
                ),
                tap_ratio = to_scalar(dict["Tap ratio (p.u.)"], default = 1.0),
                phase_shift = to_scalar(
                    dict["Phase shift (rad)"],
                    default = 0.0,
                ),
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
                    default = -Inf,
                ),
                angle_diff_max = to_scalar(
                    dict["Angle difference max (rad)"],
                    default = Inf,
                ),
                invest = to_scalar(dict["Investment cost (\$)"], default = 0.0),
                max_copy = to_scalar(
                    dict["Max number of parallel circuits"],
                    default = 1,
                ),
            )
            push!(branches, branch)
        end
    end

    sc[:branches] = branches
    sc[:branch_by_name] = Dict(b.name => b for b in branches)

    # Read contingencies
    contingencies = Contingency[]
    if "Contingencies" in keys(json)
        for (cont_name, dict) in json["Contingencies"]
            affected_branches = Branch[]
            if "Affected branches" in keys(dict)
                affected_branches =
                    [sc[:branch_by_name][b] for b in dict["Affected branches"]]
            end
            if "Affected units" in keys(dict)
                error("Unit contingencies are not currently supported")
            end
            cont = Contingency(cont_name, affected_branches)
            push!(contingencies, cont)
        end
    end
    sc[:contingencies] = contingencies
    sc[:contingencies_by_name] = Dict(c.name => c for c in contingencies)

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
    sc[:shunt_by_name] = Dict(s.name => s for s in shunts)

    buses = sc[:bus]
    shunts_by_bus = Dict(b => ShuntDevice[] for b in buses)
    for s in shunts
        push!(shunts_by_bus[s.bus], s)
    end
    sc[:shunts_by_bus] = shunts_by_bus

    branches_by_source = Dict(b => Branch[] for b in buses)
    branches_by_target = Dict(b => Branch[] for b in buses)
    for l in branches
        push!(branches_by_source[l.source], l)
        push!(branches_by_target[l.target], l)
    end
    sc[:branches_by_source_bus] = branches_by_source
    sc[:branches_by_target_bus] = branches_by_target

    return
end
