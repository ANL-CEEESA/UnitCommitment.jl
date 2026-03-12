# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

function _summary_solve(path::String; kwargs...)
    instance = UnitCommitment.read(path; kwargs...)
    model = UnitCommitment.build_model(instance, optimizer = test_optimizer())
    UnitCommitment.optimize!(model)
    return UnitCommitment.solution(model)
end

@testfunction summary_core_test begin
    sol = _summary_solve(fixture("case14/base.json"))
    summary = sol["Summary"]

    @test summary["Solver: Termination status"] == "OPTIMAL"
    @test summary["Solver: Objective value (\$)"] == 11728.84
    @test summary["Solver: Objective bound (\$)"] == 11728.84
    @test summary["Solver: Optimality gap (%)"] == 0.0

    @test summary["Bus: System peak load (MW)"] == 310.5
    @test summary["Bus: System minimum load (MW)"] == 273.4
    @test summary["Bus: Total load curtailment (MW)"] == 0.0
    @test summary["Bus: Peak load curtailment (MW)"] == 0.0
    @test summary["Solver: Has load curtailment?"] == false

    @test summary["Solver: Has branch overflow?"] == false
    @test summary["Solver: Has reserve shortfall?"] == false

    @test summary["Total penalty: Load curtailment (\$)"] == 0.0
    @test summary["Total penalty: Reserve shortfall (\$)"] == 0.0
    @test summary["Reserve: Peak shortfall (MW)"] == 0.0
end
