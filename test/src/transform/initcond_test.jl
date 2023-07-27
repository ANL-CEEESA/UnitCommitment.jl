# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using UnitCommitment, HiGHS, JuMP

function transform_initcond_test()
    @testset "generate_initial_conditions!" begin
        # Load instance
        instance = UnitCommitment.read(fixture("case118-initcond.json.gz"))
        optimizer =
            optimizer_with_attributes(HiGHS.Optimizer, MOI.Silent() => true)

        # All units should have unknown initial conditions
        for sc in instance.scenarios
            for g in sc.thermal_units
                @test g.initial_power === nothing
                @test g.initial_status === nothing
            end
        end

        # Generate initial conditions
        UnitCommitment.generate_initial_conditions!(instance, optimizer)

        # All units should now have known initial conditions
        for sc in instance.scenarios
            for g in sc.thermal_units
                @test g.initial_power !== nothing
                @test g.initial_status !== nothing
            end
        end

        # TODO: Check that initial conditions are feasible
    end
end
