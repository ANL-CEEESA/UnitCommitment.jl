# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

function _solve_dc_shiftfactors(fixture_path::String, lazy::Bool = false)
    instance = UnitCommitment.read(
        fixture(fixture_path),
        extensions = [UnitCommitment.ShiftFactorsTransmissionExt(lazy = lazy)],
    )
    model = build_model(
        instance,
        optimizer = test_optimizer(),
        variable_names = true,
    )
    if lazy
        optimize!(model, UnitCommitment.XavQiuWanThi2019.Method())
    else
        optimize!(model)
    end
    sol = solution(model)
    base_flow = sol["Line: Base Flow (MW)"]
    cont_flows = get(sol, "Line: Contingency Flow (MW)", nothing)
    return base_flow, cont_flows
end

@testfunction transmission_dc_shiftfactors_base_flow_test begin
    for lazy in [false, true]
        base_flow, _ = _solve_dc_shiftfactors("case14/base.json", lazy)

        # Verify base case flows on a few lines
        @test round.(base_flow["l1"], digits = 1) == [100.0, 100.0, 97.9, 97.5]
        @test round.(base_flow["l2"], digits = 1) == [31.7, 33.8, 32.2, 32.5]
        @test round.(base_flow["l7"], digits = 1) ==
              [-41.0, -44.0, -43.6, -42.3]
        @test round.(base_flow["l14"], digits = 1) ==
              [-92.8, -66.0, -66.0, -66.0]
        @test round.(base_flow["l20"], digits = 1) == [7.5, 9.2, 9.0, 8.3]
    end
end

@testfunction transmission_dc_shiftfactors_contingency_flow_test begin
    for lazy in [false, true]
        base_flow, cont_flows =
            _solve_dc_shiftfactors("case14/contingency.json", lazy)
        cont_flow = cont_flows["c1"]

        # Verify base case flows
        @test round.(base_flow["l1"], digits = 1) == [-8.2, -9.2, -9.3, -9.1]
        @test round.(base_flow["l3"], digits = 1) == [29.8, 13.0, 10.3, 9.3]
        @test round.(base_flow["l7"], digits = 1) ==
              [-31.3, -26.8, -23.4, -22.4]
        @test round.(base_flow["l14"], digits = 1) ==
              [-56.7, -33.0, -33.0, -33.0]
        @test round.(base_flow["l20"], digits = 1) == [12.7, 12.7, 11.1, 10.7]

        # Verify contingency flows on a few lines for first contingency
        @test round.(cont_flow["l1"], digits = 1) == [0.0, 0.0, 0.0, 0.0]
        @test round.(cont_flow["l3"], digits = 1) == [31.2, 14.5, 11.9, 10.8]
        @test round.(cont_flow["l7"], digits = 1) ==
              [-27.2, -22.3, -18.8, -17.8]
        @test round.(cont_flow["l14"], digits = 1) ==
              [-56.7, -33.0, -33.0, -33.0]
        @test round.(cont_flow["l20"], digits = 1) == [12.6, 12.6, 11.0, 10.6]
    end
end

@testfunction transmission_dc_shiftfactors_congested_flow_test begin
    for lazy in [false, true]
        base_flow, _ = _solve_dc_shiftfactors("case14/congested.json", lazy)

        # Verify base case flows on a few lines
        @test round.(base_flow["l1"], digits = 1) == [-8.0, -8.1, -6.7, -6.3]
        @test round.(base_flow["l3"], digits = 1) == [30.0, 12.2, 8.5, 7.3]
        @test round.(base_flow["l7"], digits = 1) ==
              [-35.1, -27.4, -24.7, -23.8]
        @test round.(base_flow["l14"], digits = 1) ==
              [-46.8, -33.0, -33.0, -33.0]
        @test round.(base_flow["l20"], digits = 1) == [14.8, 13.4, 12.8, 12.5]
    end
end
