# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using DataStructures
using JSON

function _migrate(json)
    version = json["Parameters"]["Version"]
    if version === nothing
        error(
            "The provided input file cannot be loaded because it does not " *
            "specify what version of UnitCommitment.jl it was written for. " *
            "Please modify the \"Parameters\" section of the file and include " *
            "a \"Version\" entry. For example: {\"Parameters\":{\"Version\":\"0.3\"}}",
        )
    end
    version = VersionNumber(version)
    version >= v"0.3" || _migrate_to_v03(json)
    version >= v"0.4" || _migrate_to_v04(json)
    version >= v"0.5" || _migrate_to_v05(json)
    return
end

function _migrate_to_v03(json)
    # Migrate reserves
    if json["Reserves"] !== nothing &&
       json["Reserves"]["Spinning (MW)"] !== nothing
        amount = json["Reserves"]["Spinning (MW)"]
        json["Reserves"] = DefaultOrderedDict(nothing)
        json["Reserves"]["r1"] = DefaultOrderedDict(nothing)
        json["Reserves"]["r1"]["Type"] = "spinning"
        json["Reserves"]["r1"]["Amount (MW)"] = amount
        for (gen_name, gen) in json["Generators"]
            if gen["Provides spinning reserves?"] == true
                gen["Reserve eligibility"] = ["r1"]
            end
        end
    end
end

function _migrate_to_v04(json)
    # Migrate thermal units
    if json["Generators"] !== nothing
        for (gen_name, gen) in json["Generators"]
            if gen["Type"] === nothing
                gen["Type"] = "Thermal"
            end
        end
    end
end

function _migrate_to_v05(json)
    # Migrate transmission lines
    if haskey(json, "Transmission lines") &&
       json["Transmission lines"] !== nothing
        for (line_name, line) in json["Transmission lines"]
            # Rename flow limit fields from MW to MVA
            if line["Normal flow limit (MW)"] !== nothing
                line["Normal flow limit (MVA)"] = line["Normal flow limit (MW)"]
                line["Normal flow limit (MW)"] = nothing
            end
            if line["Emergency flow limit (MW)"] !== nothing
                line["Emergency flow limit (MVA)"] =
                    line["Emergency flow limit (MW)"]
                line["Emergency flow limit (MW)"] = nothing
            end
        end
    end

    # Default Base MVA in parameters
    if json["Parameters"]["Base MVA"] === nothing
        json["Parameters"]["Base MVA"] = 100
    end
end
