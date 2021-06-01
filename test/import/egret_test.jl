# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using UnitCommitment

@testset "read_egret_solution" begin
    solution =
        UnitCommitment.read_egret_solution("fixtures/egret_output.json.gz")
    for attr in ["Is on", "Production (MW)", "Production cost (\$)"]
        @test attr in keys(solution)
        @test "115_STEAM_1" in keys(solution[attr])
        @test length(solution[attr]["115_STEAM_1"]) == 48
    end
    @test solution["Production cost (\$)"]["315_CT_6"][15:20] ==
          [0.0, 0.0, 884.44, 1470.71, 1470.71, 884.44]
    @test solution["Startup cost (\$)"]["315_CT_6"][15:20] ==
          [0.0, 0.0, 5665.23, 0.0, 0.0, 0.0]
    @test length(keys(solution["Is on"])) == 154
end
