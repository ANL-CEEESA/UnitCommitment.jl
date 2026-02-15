# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

@testfunction migrate_v02_test begin
    instance = UnitCommitment.read(fixture("migration/ucjl-0.2.json.gz"))
    @test length(instance.scenarios) == 1
    sc = instance.scenarios[1]
    @test length(sc.data[:reserves_by_name]["r1"].amount) == 4
    @test sc.data[:thermal_by_name]["g2"].reserves[1].name == "r1"
end

@testfunction migrate_v03_test begin
    instance = UnitCommitment.read(fixture("migration/ucjl-0.3.json.gz"))
    @test length(instance.scenarios) == 1
    sc = instance.scenarios[1]
    @test length(sc.data[:thermal]) == 6
    @test length(sc[:bus]) == 14
    @test length(sc.data[:branches]) == 20
end
