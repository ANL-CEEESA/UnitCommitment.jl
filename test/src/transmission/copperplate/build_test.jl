# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using HiGHS, JuMP, UnitCommitment

@testfunction transmission_copperplate_build_test begin
    instance = UnitCommitment.read(
        fixture("base.json"),
        extensions = [UnitCommitment.CopperPlateTransmissionExt()],
    )
    model =
        build_model(
            instance,
            optimizer = test_optimizer(),
            variable_names = true,
        ).inner

    # eq_power_balance
    # -------------------------------------------------------------------------
    @test_constr model[:eq_power_balance]["s1", 1] "ni[s1,b1,1] + ni[s1,b2,1] + ni[s1,b3,1] + ni[s1,b4,1] + ni[s1,b5,1] + ni[s1,b6,1] + ni[s1,b7,1] + ni[s1,b8,1] + ni[s1,b9,1] + ni[s1,b10,1] + ni[s1,b11,1] + ni[s1,b12,1] + ni[s1,b13,1] + ni[s1,b14,1] + ni[s1,b15,1] = 0"
    @test_constr model[:eq_power_balance]["s1", 4] "ni[s1,b1,4] + ni[s1,b2,4] + ni[s1,b3,4] + ni[s1,b4,4] + ni[s1,b5,4] + ni[s1,b6,4] + ni[s1,b7,4] + ni[s1,b8,4] + ni[s1,b9,4] + ni[s1,b10,4] + ni[s1,b11,4] + ni[s1,b12,4] + ni[s1,b13,4] + ni[s1,b14,4] + ni[s1,b15,4] = 0"
end
