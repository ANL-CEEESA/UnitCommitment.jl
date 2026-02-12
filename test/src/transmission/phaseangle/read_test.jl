# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using UnitCommitment

@testfunction transmission_phaseangle_read_test begin
    instance = UnitCommitment.read(
        fixture("tep_ieee24.json.gz"),
        extensions = [UnitCommitment.PhaseAngleTransmissionExt()],
    )
    sc = instance.scenarios[1]
    @test length(sc[:lines]) == 77
    @test sc[:lines][1].name == "l1"
    @test sc[:lines][1].source.name == "b1"
    @test sc[:lines][1].target.name == "b2"
    @test sc[:lines][1].susceptance ≈ 71.94244604316548
    @test sc[:lines][1].normal_flow_limit == [175.0]

    instance = UnitCommitment.read(fixture("case14.json.gz"))
    sc = instance.scenarios[1]
    @test length(sc[:lines]) == 20
    @test length(sc[:contingencies]) == 19

    # Line l5
    @test sc[:lines][5].name == "l5"
    @test sc[:lines][5].source.name == "b2"
    @test sc[:lines][5].target.name == "b5"
    @test sc[:lines][5].susceptance ≈ 10.037550333
    @test sc[:lines][5].normal_flow_limit == [1e8 for t in 1:4]
    @test sc[:lines][5].emergency_flow_limit == [1e8 for t in 1:4]
    @test sc[:lines][5].flow_limit_penalty == [5e3 for t in 1:4]
    @test sc[:line_by_name]["l5"].name == "l5"

    # Line l1
    @test sc[:lines][1].name == "l1"
    @test sc[:lines][1].source.name == "b1"
    @test sc[:lines][1].target.name == "b2"
    @test sc[:lines][1].susceptance ≈ 29.496860773945
    @test sc[:lines][1].normal_flow_limit == [300.0 for t in 1:4]
    @test sc[:lines][1].emergency_flow_limit == [400.0 for t in 1:4]
    @test sc[:lines][1].flow_limit_penalty == [1e3 for t in 1:4]

    # Contingencies
    @test sc[:contingencies][1].lines == [sc[:lines][1]]
    @test sc[:contingencies][1].name == "c1"
    @test sc[:contingencies_by_name]["c1"].name == "c1"
end
