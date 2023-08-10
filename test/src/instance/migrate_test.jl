# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using UnitCommitment, LinearAlgebra, JuMP, JSON, GZip

function instance_migrate_test()
    @testset "read v0.2" begin
        instance = UnitCommitment.read(fixture("/ucjl-0.2.json.gz"))
        @test length(instance.scenarios) == 1
        sc = instance.scenarios[1]
        @test length(sc.reserves_by_name["r1"].amount) == 4
        @test sc.thermal_units_by_name["g2"].reserves[1].name == "r1"
    end

    @testset "read v0.3" begin
        instance = UnitCommitment.read(fixture("/ucjl-0.3.json.gz"))
        @test length(instance.scenarios) == 1
        sc = instance.scenarios[1]
        @test length(sc.thermal_units) == 6
        @test length(sc.buses) == 14
        @test length(sc.lines) == 20
    end
end
