@testfunction components_interface_read_test begin
    instance = UnitCommitment.read(fixture("case14/interface.json"))
    sc = instance.scenarios[1]

    @test length(sc[:interfaces]) == 2
    @test haskey(sc, :interface_by_name)

    ifc1 = sc[:interface_by_name]["ifc1"]
    @test ifc1.name == "ifc1"
    @test ifc1.offset == 1
    @test length(ifc1.branches) == 2
    @test ifc1.net_flow_ub == [120.0, 120.0, 120.0, 120.0]
    @test ifc1.net_flow_lb == [-120.0, -120.0, -120.0, -120.0]
    @test ifc1.flow_limit_penalty == [5000.0, 5000.0, 5000.0, 5000.0]

    # Weights
    l1 = sc[:branch_by_name]["l1"]
    @test ifc1.weight_by_branch[l1] == 1.0

    ifc2 = sc[:interface_by_name]["ifc2"]
    @test ifc2.offset == 2
    # Time-varying upper limit
    @test ifc2.net_flow_ub == [50.0, 60.0, 60.0, 60.0]

    # Interface ISF matrix should exist (shift factors is default)
    @test haskey(sc, :interface_isf)
    @test size(sc[:interface_isf]) == (2, length(sc[:bus]) - 1)

    # No interfaces → empty list
    instance2 = UnitCommitment.read(fixture("case14/base.json"))
    sc2 = instance2.scenarios[1]
    @test length(sc2[:interfaces]) == 0
end
