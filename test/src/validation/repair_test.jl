# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using UnitCommitment, JSON, DataStructures

function validation_repair_test()
    @testset "repair!" begin
        @testset "Cost curve should be convex" begin
            json = UnitCommitment._read_json(fixture("case14.json.gz"))
            json["Generators"]["g1"]["Production cost curve (MW)"] =
                [100, 150, 200]
            json["Generators"]["g1"]["Production cost curve (\$)"] =
                [10, 25, 30]
            extensions = [UnitCommitment.ThermalExt()]
            sc = UnitCommitment._from_json(json, extensions)
            instance = UnitCommitment.UnitCommitmentInstance(
                time = sc[:time],
                scenarios = [sc],
                extensions = extensions,
            )
            @test UnitCommitment.repair!(instance) == 4
        end

        @testset "Startup limit must be greater than Pmin" begin
            json = UnitCommitment._read_json(fixture("case14.json.gz"))
            json["Generators"]["g1"]["Production cost curve (MW)"] = [100, 150]
            json["Generators"]["g1"]["Production cost curve (\$)"] = [100, 150]
            json["Generators"]["g1"]["Startup limit (MW)"] = 80
            extensions = [UnitCommitment.ThermalExt()]
            sc = UnitCommitment._from_json(json, extensions)
            instance = UnitCommitment.UnitCommitmentInstance(
                time = sc[:time],
                scenarios = [sc],
                extensions = extensions,
            )
            @test UnitCommitment.repair!(instance) == 1
        end

        @testset "Startup costs and delays must be increasing" begin
            json = UnitCommitment._read_json(fixture("case14.json.gz"))
            json["Generators"]["g1"]["Startup costs (\$)"] = [300, 200, 100]
            json["Generators"]["g1"]["Startup delays (h)"] = [8, 4, 2]
            extensions = [UnitCommitment.ThermalExt()]
            sc = UnitCommitment._from_json(json, extensions)
            instance = UnitCommitment.UnitCommitmentInstance(
                time = sc[:time],
                scenarios = [sc],
                extensions = extensions,
            )
            @test UnitCommitment.repair!(instance) == 4
        end
    end
end
