# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using UnitCommitment

@testfunction components_virtual_slice_test begin
    instance = UnitCommitment.read(fixture("virtual.json"))
    modified = UnitCommitment.slice(instance, 1:2)
    sc = modified.scenarios[1]

    # Scalar fields should be truncated
    inc1 = sc[:virtual_by_name]["vt_inc1"]
    @test inc1.price == [30.0, 30.0]
    @test inc1.max_quantity == [50.0, 50.0]

    # Time-varying fields should be truncated
    dec2 = sc[:virtual_by_name]["vt_dec2"]
    @test dec2.price == [50.0, 55.0]
    @test dec2.max_quantity == [30.0, 40.0]

    # UTC should also be truncated
    utc1 = sc[:virtual_by_name]["vt_utc1"]
    @test utc1.price == [10.0, 10.0]
    @test utc1.max_quantity == [30.0, 30.0]
end
