# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using UnitCommitment
using JuMP
using HiGHS
using JSON

function interface_optimization_test()
    @testset "interface_optimization" begin
        # case3-interface: only outbounds
        instance = UnitCommitment.read(fixture("case3-interface.json.gz"))
        model = UnitCommitment.build_model(
            instance = instance,
            optimizer = HiGHS.Optimizer,
            variable_names = true,
        )
        set_silent(model)
        UnitCommitment.optimize!(model)
        @test value(variable_by_name(model, "interface_flow[ifc1,3]")) ≈ 20.0 atol =
            0.1
        @test value(variable_by_name(model, "interface_flow[ifc1,4]")) ≈ 20.0 atol =
            0.1

        # case3-interface-2: one outbound, one inbound
        instance = UnitCommitment.read(fixture("case3-interface-2.json.gz"))
        model = UnitCommitment.build_model(
            instance = instance,
            optimizer = HiGHS.Optimizer,
            variable_names = true,
        )
        set_silent(model)
        UnitCommitment.optimize!(model)
        @test value(variable_by_name(model, "interface_flow[ifc1,1]")) ≈ 95.0 atol =
            0.1
        @test value(variable_by_name(model, "interface_flow[ifc1,2]")) ≈ 95.0 atol =
            0.1
    end
end
