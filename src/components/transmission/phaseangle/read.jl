# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

function read_json(
    json::AbstractDict,
    sc::UnitCommitmentScenario,
    ::PhaseAngleTransmissionExt,
)
    T = sc.time
    lines = TransmissionLine[]

    # Read transmission lines
    if "Transmission lines" in keys(json)
        for (line_name, dict) in json["Transmission lines"]
            line = TransmissionLine(
                name = line_name,
                offset = length(lines) + 1,
                source = sc.data[:bus_by_name][dict["Source bus"]],
                target = sc.data[:bus_by_name][dict["Target bus"]],
                susceptance = to_scalar(dict["Susceptance (S)"]),
                normal_flow_limit = to_timeseries(
                    dict["Normal flow limit (MW)"],
                    T,
                    default = [1e8 for t in 1:T],
                ),
                emergency_flow_limit = to_timeseries(
                    dict["Emergency flow limit (MW)"],
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
            push!(lines, line)
        end
    end

    sc.data[:lines] = lines
    sc.data[:line_by_name] = Dict(l.name => l for l in lines)
    return
end
