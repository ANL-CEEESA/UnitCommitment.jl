# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using UnitCommitment

@testfunction components_bus_read_test begin
    instance = UnitCommitment.read(fixture("case14/base.json"))
    sc = instance.scenarios[1]
    @test length(sc[:bus]) == 14
    @test sc[:bus][9].name == "b9"
    @test sc[:bus][9].load == [35.366, 33.255, 31.671, 31.144]
    @test sc[:bus_by_name]["b9"].name == "b9"
end
