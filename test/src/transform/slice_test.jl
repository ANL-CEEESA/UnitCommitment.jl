# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using UnitCommitment, LinearAlgebra, Cbc, JuMP, JSON, GZip

function transform_slice_test()
    @testset "slice" begin
        instance = UnitCommitment.read(fixture("case14.json.gz"))
        modified = UnitCommitment.slice(instance, 1:2)
        sc = modified.scenarios[1]

        # Should update all time-dependent fields
        @test modified.time == 2
        @test length(sc.power_balance_penalty) == 2
        @test length(sc.reserves_by_name["r1"].amount) == 2
        for u in sc.thermal_units
            @test length(u.max_power) == 2
            @test length(u.min_power) == 2
            @test length(u.must_run) == 2
            @test length(u.min_power_cost) == 2
            for s in u.cost_segments
                @test length(s.mw) == 2
                @test length(s.cost) == 2
            end
        end
        for b in sc.buses
            @test length(b.load) == 2
        end
        for l in sc.lines
            @test length(l.normal_flow_limit) == 2
            @test length(l.emergency_flow_limit) == 2
            @test length(l.flow_limit_penalty) == 2
        end
        for ps in sc.price_sensitive_loads
            @test length(ps.demand) == 2
            @test length(ps.revenue) == 2
        end

        # Should be able to build model without errors
        optimizer = optimizer_with_attributes(Cbc.Optimizer, "logLevel" => 0)
        model = UnitCommitment.build_model(
            instance = modified,
            optimizer = optimizer,
            variable_names = true,
        )
    end

    @testset "slice profiled units" begin
        instance = UnitCommitment.read(fixture("case14-profiled.json.gz"))
        modified = UnitCommitment.slice(instance, 1:2)
        sc = modified.scenarios[1]

        # Should update all time-dependent fields
        for pu in sc.profiled_units
            @test length(pu.max_power) == 2
            @test length(pu.min_power) == 2
        end

        # Should be able to build model without errors
        optimizer = optimizer_with_attributes(Cbc.Optimizer, "logLevel" => 0)
        model = UnitCommitment.build_model(
            instance = modified,
            optimizer = optimizer,
            variable_names = true,
        )
    end
end
