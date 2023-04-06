# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using DataStructures, JSON, GZip

"""

    read_egret_solution(path::String)::OrderedDict

Read a JSON solution file produced by EGRET and transforms it into a
dictionary having the same structure as the one produced by
UnitCommitment.solution(model).
"""
function read_egret_solution(path::String)::OrderedDict
    egret = _read_json(path)
    T = length(egret["system"]["time_keys"])

    solution = OrderedDict()
    is_on = solution["Is on"] = OrderedDict()
    production = solution["Thermal production (MW)"] = OrderedDict()
    reserve = solution["Reserve (MW)"] = OrderedDict()
    production_cost = solution["Thermal production cost (\$)"] = OrderedDict()
    startup_cost = solution["Startup cost (\$)"] = OrderedDict()

    for (gen_name, gen_dict) in egret["elements"]["generator"]
        if endswith(gen_name, "_T") || endswith(gen_name, "_R")
            gen_name = gen_name[1:end-2]
        end
        if "commitment" in keys(gen_dict)
            is_on[gen_name] = gen_dict["commitment"]["values"]
        else
            is_on[gen_name] = ones(T)
        end
        production[gen_name] = gen_dict["pg"]["values"]
        if "rg" in keys(gen_dict)
            reserve[gen_name] = gen_dict["rg"]["values"]
        else
            reserve[gen_name] = zeros(T)
        end
        startup_cost[gen_name] = zeros(T)
        production_cost[gen_name] = zeros(T)
        if "commitment_cost" in keys(gen_dict)
            for t in 1:T
                x = gen_dict["commitment"]["values"][t]
                commitment_cost = gen_dict["commitment_cost"]["values"][t]
                prod_above_cost = gen_dict["production_cost"]["values"][t]
                prod_base_cost = gen_dict["p_cost"]["values"][1][2] * x
                startup_cost[gen_name][t] = commitment_cost - prod_base_cost
                production_cost[gen_name][t] = prod_above_cost + prod_base_cost
            end
        end
    end
    return solution
end
