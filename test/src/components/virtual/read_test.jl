# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using UnitCommitment

@testfunction components_virtual_read_test begin
    instance = UnitCommitment.read(fixture("virtual.json"))
    sc = instance.scenarios[1]
    @test length(sc[:virtual]) == 4

    # INC
    inc1 = sc[:virtual_by_name]["vt_inc1"]
    @test inc1.name == "vt_inc1"
    @test inc1.type == :inc
    @test inc1.bus_source.name == "b1"
    @test inc1.bus_sink.name == "b1"
    @test inc1.price == [30.0 for _ in 1:4]
    @test inc1.max_quantity == [50.0 for _ in 1:4]

    # DEC (scalar)
    dec1 = sc[:virtual_by_name]["vt_dec1"]
    @test dec1.type == :dec
    @test dec1.bus_source.name == "b3"
    @test dec1.bus_sink.name == "b3"
    @test dec1.price == [60.0 for _ in 1:4]
    @test dec1.max_quantity == [40.0 for _ in 1:4]

    # DEC (time-varying)
    dec2 = sc[:virtual_by_name]["vt_dec2"]
    @test dec2.type == :dec
    @test dec2.price == [50.0, 55.0, 45.0, 52.0]
    @test dec2.max_quantity == [30.0, 40.0, 20.0, 35.0]

    # UTC
    utc1 = sc[:virtual_by_name]["vt_utc1"]
    @test utc1.type == :utc
    @test utc1.bus_source.name == "b1"
    @test utc1.bus_sink.name == "b3"
    @test utc1.price == [10.0 for _ in 1:4]
    @test utc1.max_quantity == [30.0 for _ in 1:4]
end

@testfunction components_virtual_read_empty_test begin
    instance = UnitCommitment.read(fixture("case14/base.json"))
    sc = instance.scenarios[1]
    @test length(sc[:virtual]) == 0
end
