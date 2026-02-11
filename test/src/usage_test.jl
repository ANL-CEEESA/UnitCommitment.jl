# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

@testfunction usage_deterministic_test begin
    instance = UnitCommitment.read(
        fixture("case14/base.json"),
        extensions = [UnitCommitment.ShiftFactorsTransmissionExt()],
    )
    model = build_model(
        instance,
        optimizer = test_optimizer(),
        variable_names = true,
    )
    optimize!(model)
    sol = solution(model)
    @test sol["Thermal: Is on"]["g1"] == [1.0, 1.0, 1.0, 1.0]
    @test sol["Thermal: Is on"]["g2"] == [1.0, 1.0, 1.0, 1.0]
end

@testfunction usage_stochastic_test begin
    instance = UnitCommitment.read(
        [fixture("case14/base.json"), fixture("case14/congested.json")],
        extensions = [UnitCommitment.ShiftFactorsTransmissionExt()],
    )
    model = build_model(
        instance,
        optimizer = test_optimizer(),
        variable_names = true,
    )
    optimize!(model)
    sol = solution(model)

    @test sol["base"]["Thermal: Is on"]["g1"] == [1.0, 0.0, 0.0, 0.0]
    @test sol["base"]["Thermal: Is on"]["g2"] == [1.0, 1.0, 1.0, 1.0]
    @test round.(sol["base"]["Thermal: Production (MW)"]["g1"]) ==
          [130.0, 0.0, 0.0, 0.0]
    @test round.(sol["base"]["Thermal: Production (MW)"]["g2"]) ==
          [42.0, 40.0, 28.0, 23.0]

    @test sol["congested"]["Thermal: Is on"]["g1"] == [1.0, 0.0, 0.0, 0.0]
    @test sol["congested"]["Thermal: Is on"]["g2"] == [1.0, 1.0, 1.0, 1.0]
    @test round.(sol["congested"]["Thermal: Production (MW)"]["g1"]) ==
          [100.0, 0.0, 0.0, 0.0]
    @test round.(sol["congested"]["Thermal: Production (MW)"]["g2"]) ==
          [20.0, 77.0, 66.0, 63.0]
end

@testfunction usage_deprecated_api_test begin
    instance = UnitCommitment.read(
        fixture("case14/base.json"),
        extensions = [UnitCommitment.ShiftFactorsTransmissionExt()],
    )
    model = build_model(
        instance = instance,
        optimizer = test_optimizer(),
        variable_names = true,
    )
    optimize!(model)
    sol = solution(model)
    @test sol["Thermal: Is on"]["g1"] == [1.0, 1.0, 1.0, 1.0]
    @test sol["Thermal: Is on"]["g2"] == [1.0, 1.0, 1.0, 1.0]
end
