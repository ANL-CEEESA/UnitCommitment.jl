# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

function read_json(
    json::AbstractDict,
    sc::UnitCommitmentScenario,
    ::InterfaceLimitsExt,
)
    T = sc[:time]
    interfaces = Interface[]

    if "Interfaces" in keys(json)
        for (ifc_name, dict) in json["Interfaces"]
            lines = TransmissionLine[]
            weight_by_line = Dict{TransmissionLine,Float64}()

            if "Lines" in keys(dict) && dict["Lines"] !== nothing
                for (line_name, weight) in dict["Lines"]
                    line = sc[:line_by_name][line_name]
                    push!(lines, line)
                    weight_by_line[line] = Float64(weight)
                end
            end

            ifc = Interface(
                name = ifc_name,
                offset = length(interfaces) + 1,
                lines = lines,
                weight_by_line = weight_by_line,
                net_flow_ub = to_timeseries(
                    to_scalar(dict["Net flow upper limit (MW)"], default = Inf),
                    T,
                ),
                net_flow_lb = to_timeseries(
                    to_scalar(
                        dict["Net flow lower limit (MW)"],
                        default = -Inf,
                    ),
                    T,
                ),
                flow_limit_penalty = to_timeseries(
                    to_scalar(
                        dict["Flow limit penalty (\$/MW)"],
                        default = 5000.0,
                    ),
                    T,
                ),
            )
            push!(interfaces, ifc)
        end
    end

    sc[:interfaces] = interfaces
    sc[:interface_by_name] = Dict(ifc.name => ifc for ifc in interfaces)

    # Compute interface ISF matrix if shift factors are available
    if haskey(sc, :isf) && !isempty(interfaces)
        isf = sc[:isf]
        B_minus_1 = size(isf, 2)
        I = length(interfaces)
        ifc_isf = zeros(I, B_minus_1)
        for ifc in interfaces
            for line in ifc.lines
                w = ifc.weight_by_line[line]
                for b in 1:B_minus_1
                    ifc_isf[ifc.offset, b] += w * isf[line.offset, b]
                end
            end
        end
        sc[:interface_isf] = ifc_isf
    end
end
