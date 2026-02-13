# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using UnitCommitment

@testfunction transmission_ac_slice_test begin
    instance = UnitCommitment.read(
        fixture("ac_3bus.json"),
        extensions = [UnitCommitment.ACTransmissionExt()],
    )
    modified = UnitCommitment.slice(instance, 1:1)
    sc = modified.scenarios[1]

    # Branch l1
    l1 = sc[:ac_branch_by_name]["l1"]
    @test l1.normal_flow_limit == [150.0]
    @test l1.emergency_flow_limit == [200.0]
    @test l1.flow_limit_penalty == [5000.0]

    # Branch l2
    l2 = sc[:ac_branch_by_name]["l2"]
    @test l2.normal_flow_limit == [100.0]
    @test l2.emergency_flow_limit == [130.0]
    @test l2.flow_limit_penalty == [5000.0]

    # Branch l3
    l3 = sc[:ac_branch_by_name]["l3"]
    @test l3.normal_flow_limit == [120.0]
    @test l3.emergency_flow_limit == [160.0]
    @test l3.flow_limit_penalty == [5000.0]

    # Shunt device
    sh1 = sc[:shunts][1]
    @test sh1.status == [true]
end
