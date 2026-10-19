# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using DataStructures
using UnitCommitment

@testfunction regression_github_issue_57_test begin
    instance = UnitCommitment.read(fixture("issue-0057.json.gz"))
    model = build_model(instance, optimizer = test_optimizer())
    optimize!(model)
    sol = solution(model)
    @test sol["Thermal: Production (MW)"]["gen_524d4c85"][1] == 90.0
end

@testfunction regression_github_issue_61_test begin
    instance = UnitCommitment.read(fixture("issue-0061.json.gz"))
    @test UnitCommitment.validate(
        instance,
        OrderedDict(
            "Thermal: Production (MW)" => OrderedDict("g1" => [50.0]),
            "Thermal: Production cost (\$)" => OrderedDict("g1" => [25.0]),
            "Thermal: Startup cost (\$)" => OrderedDict("g1" => [100.0]),
            "Thermal: Shutdown cost (\$)" => OrderedDict("g1" => [0.0]),
            "Thermal: Is on" => OrderedDict("g1" => [1.0]),
            "Reserve: Provided (MW)" => OrderedDict(),
            "Bus: Load curtail (MW)" => OrderedDict("b1" => [40.0]),
            "Branch: Base flow (MW)" => OrderedDict(),
            "Branch: Overflow (MW)" => OrderedDict(),
        ),
    )
end
