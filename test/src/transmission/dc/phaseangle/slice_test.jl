# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using UnitCommitment

@testfunction transmission_dc_phaseangle_slice_test begin
    instance = UnitCommitment.read(fixture("case14.json.gz"))
    modified = UnitCommitment.slice(instance, 1:2)
    sc = modified.scenarios[1]

    # l1: has distinct flow limits
    l1 = sc[:line_by_name]["l1"]
    @test l1.normal_flow_limit == [300.0, 300.0]
    @test l1.emergency_flow_limit == [400.0, 400.0]
    @test l1.flow_limit_penalty == [1000.0, 1000.0]
    @test l1.invest == [0.0, 0.0]

    # l2: default limits
    l2 = sc[:line_by_name]["l2"]
    @test l2.normal_flow_limit == [1.0e8, 1.0e8]
    @test l2.emergency_flow_limit == [1.0e8, 1.0e8]
    @test l2.flow_limit_penalty == [5000.0, 5000.0]
    @test l2.invest == [0.0, 0.0]
end
