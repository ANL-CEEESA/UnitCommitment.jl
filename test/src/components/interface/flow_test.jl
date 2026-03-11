@testfunction components_interface_flow_test begin
    # Shift factors
    instance = UnitCommitment.read(
        fixture("case14/interface.json"),
        extensions = [UnitCommitment.ShiftFactorsTransmissionExt(lazy = false)],
    )
    model = build_model(instance, optimizer = test_optimizer())
    optimize!(model)
    sol = solution(model)

    @test haskey(sol, "Interface: Flow (MW)")
    @test haskey(sol, "Interface: Overflow (MW)")
    @test haskey(sol, "Interface: Overflow penalty (\$)")

    ifc1_overflow = sol["Interface: Overflow (MW)"]["ifc1"]

    # ifc1 should be non-binding (no overflow)
    @test all(v -> v < 0.01, ifc1_overflow)

    # Validate solution (recomputes flows and checks bounds)
    @test UnitCommitment.validate(instance, sol)

    # Phase angle
    instance2 = UnitCommitment.read(
        fixture("case14/interface.json"),
        extensions = [UnitCommitment.PhaseAngleTransmissionExt()],
    )
    model2 = build_model(instance2, optimizer = test_optimizer())
    optimize!(model2)
    sol2 = solution(model2)

    @test haskey(sol2, "Interface: Flow (MW)")
    @test UnitCommitment.validate(instance2, sol2)
end
