# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using HiGHS, JuMP, UnitCommitment

@testfunction components_thermal_reserves_cascading_test begin
    instance = UnitCommitment.read(fixture("cascading.json"))
    sc = instance.scenarios[1]

    # Verify reserve parsing
    @test length(sc[:reserves]) == 3
    r1 = sc[:reserves_by_name]["r1"]
    r2 = sc[:reserves_by_name]["r2"]
    r3 = sc[:reserves_by_name]["r3"]

    @test r1.type == :spinning
    @test r2.type == :non_spinning
    @test r3.type == :spinning

    # Verify parent links
    @test r1.parent === r2
    @test r2.parent === r3
    @test r3.parent === nothing

    # Verify precomputed descendants
    @test isempty(r1.descendants)
    @test length(r2.descendants) == 1
    @test r1 in r2.descendants
    @test length(r3.descendants) == 2
    @test r2 in r3.descendants
    @test r1 in r3.descendants

    # Verify reserve eligibility
    g2 = sc[:thermal_by_name]["g2"]
    @test length(g2.reserves) == 2
    @test any(r -> r.name == "r2", g2.reserves)
    @test g2.non_spinning_capacity == 80.0

    g1 = sc[:thermal_by_name]["g1"]
    @test length(g1.reserves) == 2
    @test g1.non_spinning_capacity == 0.0

    # Build model and verify constraints
    model =
        build_model(
            instance,
            optimizer = test_optimizer(),
            variable_names = true,
        ).inner

    # Verify non-spinning reserve variables exist
    @test_continuous_var model[:reserve]["s1", "r2", "g2", 1] lb = 0

    # Verify eq_ns_reserve_capacity
    @test_constr(
        model[:eq_ns_reserve_capacity]["s1", "r2", "g2", 1],
        "80 is_on[g2,1] + reserve[s1,r2,g2,1] ≤ 80"
    )

    # Verify eq_min_reserve (cascading)
    @test_constr(
        model[:eq_min_reserve]["s1", "r1", 1],
        "reserve_shortfall[s1,r1,1] + reserve[s1,r1,g1,1] + reserve[s1,r1,g2,1] + reserve[s1,r1,g3,1] ≥ 50"
    )
    @test_constr(
        model[:eq_min_reserve]["s1", "r2", 1],
        "reserve_shortfall[s1,r2,1] + reserve[s1,r1,g1,1] + reserve[s1,r1,g2,1] + reserve[s1,r2,g2,1] + reserve[s1,r1,g3,1] ≥ 100"
    )
    @test_constr(
        model[:eq_min_reserve]["s1", "r3", 1],
        "reserve_shortfall[s1,r3,1] + reserve[s1,r1,g1,1] + reserve[s1,r3,g1,1] + reserve[s1,r1,g2,1] + reserve[s1,r2,g2,1] + reserve[s1,r1,g3,1] + reserve[s1,r3,g3,1] ≥ 200"
    )
end

@testfunction components_thermal_reserves_cycle_test begin
    # Test that _validate_no_cycles catches cycles
    r1 = UnitCommitment.Reserve(
        name = "r1",
        type = :spinning,
        amount = [0.0],
        thermal_units = [],
        shortfall_penalty = -1.0,
    )
    r2 = UnitCommitment.Reserve(
        name = "r2",
        type = :spinning,
        amount = [0.0],
        thermal_units = [],
        shortfall_penalty = -1.0,
    )
    r1.parent = r2
    r2.parent = r1
    @test_throws ErrorException UnitCommitment._validate_no_cycles([r1, r2])
end
