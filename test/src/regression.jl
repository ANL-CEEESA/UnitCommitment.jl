# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using UnitCommitment

@testfunction regression_github_issue_57_test begin
    instance = UnitCommitment.read(fixture("issue-0057.json.gz"))
    model = build_model(instance, optimizer = test_optimizer())
    optimize!(model)
    sol = solution(model)
    @test sol["Thermal: Production (MW)"]["gen_524d4c85"][1] == 90.0
end
