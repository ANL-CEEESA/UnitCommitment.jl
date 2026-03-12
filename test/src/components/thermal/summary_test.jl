# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

@testfunction thermal_summary_test begin
    sol = _summary_solve(fixture("case14/base.json"))
    summary = sol["Summary"]

    @test summary["Thermal: Total production cost (\$)"] == 25528.84
    @test summary["Thermal: Total startup cost (\$)"] == 6200.0
    @test summary["Thermal: Total shutdown cost (\$)"] == 0.0
    @test summary["Thermal: Peak production (MW)"] == 360.5
    @test summary["Thermal: Peak capacity online (MW)"] == 575.0
    @test summary["Thermal: Average utilization (%)"] == 58.9
    @test summary["Thermal: Total startups"] == 5
    @test summary["Thermal: Total shutdowns"] == 0
    @test !haskey(summary, "Thermal: Total investment cost (\$)")
    @test !haskey(summary, "Thermal: Units invested")
end
