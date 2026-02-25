# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using HiGHS, JuMP, UnitCommitment

@testfunction transmission_copperplate_build_test begin
    instance = UnitCommitment.read(
        fixture("case5/base.json"),
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
    @test_constr model[:eq_power_balance]["s1", 1] "ni[s1,b1,1] + ni[s1,b2,1] + ni[s1,b3,1] + ni[s1,b4,1] + ni[s1,b5,1] = 0"
end
