# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using UnitCommitment

@testfunction transform_slice_test begin
    instance = UnitCommitment.read(fixture("case14.json.gz"))
    modified = UnitCommitment.slice(instance, 1:2)
    sc = modified.scenarios[1]

    @test modified.time == 2
    @test sc[:power_balance_penalty] == [1000.0, 1000.0]

    @test sc[:bus_by_name]["b1"].load == [0.0, 0.0]
    @test sc[:bus_by_name]["b3"].load == [112.93263, 106.19039]
    @test sc[:bus_by_name]["b9"].load == [35.36638, 33.25495]
    @test sc[:bus_by_name]["b14"].load == [17.86302, 16.79657]

    # Extensions should survive through slice
    @test length(modified.extensions) == length(instance.extensions)
    @test all(
        typeof(e) == typeof(orig_e)
        for (e, orig_e) in zip(modified.extensions, instance.extensions)
    )
end
