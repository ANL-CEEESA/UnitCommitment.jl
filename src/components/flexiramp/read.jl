# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

function read_json(
    json::AbstractDict,
    sc::UnitCommitmentScenario,
    ::FlexirampExt,
)
    T = sc[:time]
    reserves = FlexirampReserve[]
    name_to_reserve = Dict{String,FlexirampReserve}()

    if "Reserves" in keys(json)
        for (reserve_name, dict) in json["Reserves"]
            lowercase(dict["Type"]) == "flexiramp" || continue
            r = FlexirampReserve(
                name = reserve_name,
                amount = to_timeseries(dict["Amount (MW)"], T),
                thermal_units = [],
                shortfall_penalty = to_scalar(
                    dict["Shortfall penalty (\$/MW)"],
                    default = -1,
                ),
            )
            name_to_reserve[reserve_name] = r
            push!(reserves, r)
        end
    end

    # Link generators to flexiramp reserves via "Reserve eligibility"
    if haskey(sc, :thermal_by_name)
        for (unit_name, dict) in json["Generators"]
            haskey(sc[:thermal_by_name], unit_name) || continue
            g = sc[:thermal_by_name][unit_name]
            if "Reserve eligibility" in keys(dict)
                for n in dict["Reserve eligibility"]
                    if haskey(name_to_reserve, n)
                        push!(name_to_reserve[n].thermal_units, g)
                    end
                end
            end
        end
    end

    sc[:flexiramp_reserves] = reserves
    sc[:flexiramp_reserves_by_name] = name_to_reserve
    return nothing
end
