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
            branches = Branch[]
            weight_by_branch = Dict{Branch,Float64}()

            if "Branches" in keys(dict) && dict["Branches"] !== nothing
                for (branch_name, weight) in dict["Branches"]
                    branch = sc[:branch_by_name][branch_name]
                    push!(branches, branch)
                    weight_by_branch[branch] = Float64(weight)
                end
            end

            ifc = Interface(
                name = ifc_name,
                offset = length(interfaces) + 1,
                branches = branches,
                weight_by_branch = weight_by_branch,
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
            for branch in ifc.branches
                w = ifc.weight_by_branch[branch]
                for b in 1:B_minus_1
                    ifc_isf[ifc.offset, b] += w * isf[branch.offset, b]
                end
            end
        end
        sc[:interface_isf] = ifc_isf
    end
end
