# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using UnitCommitment, LinearAlgebra, Cbc, JuMP, JSON, GZip

@testset "read v0.2" begin
    instance = UnitCommitment.read("$FIXTURES/ucjl-0.2.json.gz")
    @test length(instance.reserves_by_name["r1"].amount) == 4
    @test instance.units_by_name["g2"].reserves[1].name == "r1"
end

@testset "read v0.3" begin
    instance = UnitCommitment.read("$FIXTURES/ucjl-0.3.json.gz")
    @test length(instance.units) == 6
    @test length(instance.buses) == 14
    @test length(instance.lines) == 20
end

@testset "read v0.4" begin
    instance = UnitCommitment.read("$FIXTURES/ucjl-0.4.json.gz")
    @test length(instance.units) == 6
    @test length(instance.buses) == 14
    @test length(instance.lines) == 20
    @test length(instance.profiled_units) == 2
end
