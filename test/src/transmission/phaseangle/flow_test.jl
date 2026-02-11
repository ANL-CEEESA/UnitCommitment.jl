# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

@testfunction transmission_phaseangle_flow_test begin
    instance = UnitCommitment.read(
        fixture("case14/base.json"),
        extensions = [UnitCommitment.PhaseAngleTransmissionExt()],
    )
    model = build_model(
        instance,
        optimizer = test_optimizer(),
        variable_names = true,
    )

    # Fix thermal unit is_on status
    expected_is_on = Dict(
        "g1" => [1.0, 1.0, 1.0, 1.0],
        "g2" => [1.0, 1.0, 1.0, 1.0],
        "g3" => [1.0, 1.0, 1.0, 1.0],
        "g4" => [1.0, 1.0, 1.0, 1.0],
        "g5" => [1.0, 1.0, 1.0, 1.0],
        "g6" => [0.0, 0.0, 0.0, 0.0],
    )
    for (g_name, values) in expected_is_on
        for (t, value) in enumerate(values)
            JuMP.fix(model.inner[:is_on][g_name, t], value)
        end
    end

    optimize!(model)
    sol = solution(model)
    base_flow = sol["Line: Base Flow (MW)"]

    # Verify base case flows on a few lines
    @test round.(base_flow["l1"], digits = 1) == [100.0, 100.0, 97.9, 97.5]
    @test round.(base_flow["l2"], digits = 1) == [31.7, 33.8, 32.2, 32.5]
    @test round.(base_flow["l7"], digits = 1) == [-41.0, -44.0, -43.6, -42.3]
    @test round.(base_flow["l14"], digits = 1) == [-92.8, -66.0, -66.0, -66.0]
    @test round.(base_flow["l20"], digits = 1) == [7.5, 9.2, 9.0, 8.3]
end
