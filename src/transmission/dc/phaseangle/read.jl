# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using SparseArrays

function read_json(
    json::AbstractDict,
    sc::UnitCommitmentScenario,
    ::PhaseAngleTransmissionExt,
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
                susceptance = if x != 0.0
                    x / (r^2 + x^2)
                else
                    to_scalar(dict["Susceptance (p.u.)"])
                end,
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
                invest = to_timeseries(
                    to_scalar(dict["Investment cost (\$)"], default = 0.0),
                    T,
                ),
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
    sc[:contingencies_by_name] = Dict(c.name => c for c in contingencies)
    sc[:contingencies] = contingencies

    return
end
