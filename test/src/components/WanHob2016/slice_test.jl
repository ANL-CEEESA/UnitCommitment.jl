# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using UnitCommitment

@testfunction components_flexiramp_slice_test begin
    instance = UnitCommitment.read(
        fixture("case14/flex.json"),
        extensions = [UnitCommitment.WanHob2016.FlexirampExt()],
    )
    modified = UnitCommitment.slice(instance, 2:4)
    sc = modified.scenarios[1]

    r1 = sc[:flexiramp_reserves_by_name]["r1"]
    @test r1.amount ≈ [23.65273, 27.41784, 25.34057]

    r2 = sc[:flexiramp_reserves_by_name]["r2"]
    @test r2.amount ≈ [18.0, 20.0, 17.0]
end
