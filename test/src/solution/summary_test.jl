# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

@testfunction summary_test begin
    instance = UnitCommitment.read(path; kwargs...)
    model = UnitCommitment.build_model(instance, optimizer = test_optimizer())
    UnitCommitment.optimize!(model)
    sol = UnitCommitment.solution(model)
    summary = sol["Summary"]

    @test summary["Branch: Branches with overflow"] == 0
    @test summary["Branch: Congested branches"] == 1
    @test summary["Branch: Peak total overflow (MW)"] == 0.0
    @test summary["Bus: Peak load curtailment (MW)"] == 0.0
    @test summary["Bus: System minimum load (MW)"] == 273.43
    @test summary["Bus: System peak load (MW)"] == 310.51
    @test summary["Bus: Total fixed load expense (\$)"] == 46086.42
    @test summary["Bus: Total load curtailment (MW)"] == 0.0
    @test summary["LMP: Average (\$/MWh)"] == 39.94
    @test summary["LMP: Minimum (\$/MWh)"] == 38.04
    @test summary["LMP: Peak (\$/MWh)"] == 46.09
    @test summary["Price-sensitive load: Total demand served (MW)"] == 200.0
    @test summary["Price-sensitive load: Total expense (\$)"] == 7977.37
    @test summary["Profiled: Total curtailment (MW)"] == 0.0
    @test summary["Profiled: Total production cost (\$)"] == 0
    @test summary["Reserve: Peak shortfall (MW)"] == 0.0
    @test summary["Solver: Has branch overflow?"] == false
    @test summary["Solver: Has load curtailment?"] == false
    @test summary["Solver: Has reserve shortfall?"] == false
    @test summary["Solver: Objective bound"] == 11728.84
    @test summary["Solver: Objective value (\$)"] == 11728.84
    @test summary["Solver: Optimality gap (%)"] == 0.0
    @test summary["Solver: Termination status"] == "OPTIMAL"
    @test summary["Storage: Peak charging rate (MW)"] == 0
    @test summary["Storage: Peak discharging rate (MW)"] == 0
    @test summary["Storage: Round-trip loss (MWh)"] == 0.0
    @test summary["Storage: Total cost (\$)"] == 0
    @test summary["Storage: Total energy charged (MWh)"] == 0.0
    @test summary["Storage: Total energy discharged (MWh)"] == 0.0
    @test summary["Thermal: Average utilization (%)"] == 58.87
    @test summary["Thermal: Peak capacity online (MW)"] == 575.0
    @test summary["Thermal: Peak production (MW)"] == 360.5
    @test summary["Thermal: Total production cost (\$)"] == 25528.84
    @test summary["Thermal: Total shutdown cost (\$)"] == 0.0
    @test summary["Thermal: Total shutdowns"] == 0
    @test summary["Thermal: Total startup cost (\$)"] == 6200.0
    @test summary["Thermal: Total startups"] == 5
    @test summary["Total penalty: Branch overflow (\$)"] == 0.0
    @test summary["Total penalty: Load curtailment (\$)"] == 0.0
    @test summary["Total penalty: Reserve shortfall (\$)"] == 0.0
    @test summary["Virtual: Net objective cost (\$)"] == 0.0
    @test summary["Virtual: Total DEC cleared (MW)"] == 0.0
    @test summary["Virtual: Total INC cleared (MW)"] == 0.0
    @test summary["Virtual: Total revenue (\$)"] == 0
    @test summary["Virtual: Total UTC cleared (MW)"] == 0.0
end
