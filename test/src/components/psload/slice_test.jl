# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using UnitCommitment

@testfunction components_psload_slice_test begin
    instance = UnitCommitment.read(fixture("case14.json.gz"))
    modified = UnitCommitment.slice(instance, 1:2)
    sc = modified.scenarios[1]

    ps1 = sc[:psload_by_name]["ps1"]
    @test ps1.demand == [50.0, 50.0]
    @test ps1.revenue == [100.0, 100.0]
end
