@testfunction components_interface_slice_test begin
    instance = UnitCommitment.read(fixture("case14/interface.json"))
    modified = UnitCommitment.slice(instance, 2:4)
    sc = modified.scenarios[1]

    ifc1 = sc[:interface_by_name]["ifc1"]
    @test ifc1.net_flow_ub == [120.0, 120.0, 120.0]
    @test ifc1.net_flow_lb == [-120.0, -120.0, -120.0]
    @test ifc1.flow_limit_penalty == [5000.0, 5000.0, 5000.0]

    ifc2 = sc[:interface_by_name]["ifc2"]
    @test ifc2.net_flow_ub == [60.0, 60.0, 60.0]
end
