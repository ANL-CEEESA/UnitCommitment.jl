# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using UnitCommitment

@testfunction transmission_read_test begin
    # AC fixture ---------------------------------------------------------------
    instance = UnitCommitment.read(
        fixture("3bus/ac.json"),
        extensions = [UnitCommitment.ACTransmissionExt()],
    )
    sc = instance.scenarios[1]

    # AC branches
    @test length(sc[:branches]) == 3

    # Branch l1
    @test sc[:branches][1].name == "l1"
    @test sc[:branches][1].source.name == "b1"
    @test sc[:branches][1].target.name == "b2"
    @test sc[:branches][1].resistance ≈ 0.01
    @test sc[:branches][1].reactance ≈ 0.05
    @test sc[:branches][1].shunt_susceptance ≈ 0.04
    @test sc[:branches][1].shunt_conductance ≈ 0.0
    @test sc[:branches][1].tap_ratio ≈ 1.0
    @test sc[:branches][1].phase_shift ≈ 0.0
    @test sc[:branches][1].normal_flow_limit == [150.0]
    @test sc[:branches][1].emergency_flow_limit == [200.0]
    @test sc[:branches][1].flow_limit_penalty == [5000.0]

    # Branch l2 (transformer: tap != 1.0)
    @test sc[:branches][2].name == "l2"
    @test sc[:branches][2].source.name == "b1"
    @test sc[:branches][2].target.name == "b3"
    @test sc[:branches][2].resistance ≈ 0.02
    @test sc[:branches][2].reactance ≈ 0.06
    @test sc[:branches][2].shunt_susceptance ≈ 0.03
    @test sc[:branches][2].shunt_conductance ≈ 0.0
    @test sc[:branches][2].tap_ratio ≈ 1.05
    @test sc[:branches][2].phase_shift ≈ 0.0
    @test sc[:branches][2].normal_flow_limit == [100.0]
    @test sc[:branches][2].emergency_flow_limit == [130.0]
    @test sc[:branches][2].flow_limit_penalty == [5000.0]

    # Branch l3
    @test sc[:branches][3].name == "l3"
    @test sc[:branches][3].source.name == "b2"
    @test sc[:branches][3].target.name == "b3"
    @test sc[:branches][3].resistance ≈ 0.015
    @test sc[:branches][3].reactance ≈ 0.04
    @test sc[:branches][3].shunt_susceptance ≈ 0.025
    @test sc[:branches][3].shunt_conductance ≈ 0.0
    @test sc[:branches][3].tap_ratio ≈ 1.0
    @test sc[:branches][3].phase_shift ≈ 0.0
    @test sc[:branches][3].normal_flow_limit == [120.0]
    @test sc[:branches][3].emergency_flow_limit == [160.0]
    @test sc[:branches][3].flow_limit_penalty == [5000.0]

    # Branch name lookup
    @test sc[:branch_by_name]["l2"].name == "l2"

    # Shunt devices
    @test length(sc[:shunts]) == 1
    @test sc[:shunts][1].name == "sh1"
    @test sc[:shunts][1].bus.name == "b2"
    @test sc[:shunts][1].conductance ≈ 0.0
    @test sc[:shunts][1].susceptance ≈ 0.05
    @test sc[:shunts][1].status == [true]

    # DC Phase Angle fixture (TEP IEEE 24) -------------------------------------
    instance = UnitCommitment.read(
        fixture("tep_ieee24.json.gz"),
        extensions = [UnitCommitment.PhaseAngleTransmissionExt()],
    )
    sc = instance.scenarios[1]
    @test length(sc[:branches]) == 77
    @test sc[:branches][1].name == "l1"
    @test sc[:branches][1].source.name == "b1"
    @test sc[:branches][1].target.name == "b2"
    @test sc[:branches][1].susceptance ≈ 0.7194244604316548
    @test sc[:branches][1].normal_flow_limit == [175.0]

    # DC Phase Angle fixture (case 14) -----------------------------------------
    instance = UnitCommitment.read(fixture("case14.json.gz"))
    sc = instance.scenarios[1]
    @test length(sc[:branches]) == 20
    @test length(sc[:contingencies]) == 19

    # Line l5
    @test sc[:branches][5].name == "l5"
    @test sc[:branches][5].source.name == "b2"
    @test sc[:branches][5].target.name == "b5"
    @test sc[:branches][5].susceptance ≈ 0.10037550333530765
    @test sc[:branches][5].normal_flow_limit == [1e8 for t in 1:4]
    @test sc[:branches][5].emergency_flow_limit == [1e8 for t in 1:4]
    @test sc[:branches][5].flow_limit_penalty == [5e3 for t in 1:4]
    @test sc[:branch_by_name]["l5"].name == "l5"

    # Line l1
    @test sc[:branches][1].name == "l1"
    @test sc[:branches][1].source.name == "b1"
    @test sc[:branches][1].target.name == "b2"
    @test sc[:branches][1].susceptance ≈ 0.2949686077394506
    @test sc[:branches][1].normal_flow_limit == [300.0 for t in 1:4]
    @test sc[:branches][1].emergency_flow_limit == [400.0 for t in 1:4]
    @test sc[:branches][1].flow_limit_penalty == [1e3 for t in 1:4]

    # Contingencies
    @test sc[:contingencies][1].branches == [sc[:branches][1]]
    @test sc[:contingencies][1].name == "c1"
    @test sc[:contingencies_by_name]["c1"].name == "c1"
end
