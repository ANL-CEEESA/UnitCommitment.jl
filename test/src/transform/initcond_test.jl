# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using UnitCommitment, JSON, HiGHS, JuMP

function _read_without_initcond(path)
    json = JSON.parsefile(path)
    for (_, gen) in get(json, "Generators", Dict())
        delete!(gen, "Initial status (h)")
        delete!(gen, "Initial power (MW)")
    end
    tmpfile = tempname() * ".json"
    open(tmpfile, "w") do io
        return JSON.print(io, json)
    end
    return UnitCommitment.read(tmpfile)
end

@testfunction transform_initcond_test begin
    instance = _read_without_initcond(fixture("case14/base.json"))

    # All units should have unknown initial conditions
    for g in instance.scenarios[1][:thermal]
        @test g.initial_power === nothing
        @test g.initial_status === nothing
    end

    UnitCommitment.generate_initial_conditions!(instance, test_optimizer())

    # All units should now have known initial conditions
    for g in instance.scenarios[1][:thermal]
        @test g.initial_power !== nothing
        @test g.initial_status !== nothing
    end

    sc = instance.scenarios[1]
    by_name = Dict(g.name => g for g in sc[:thermal])

    @test by_name["g1"].initial_power ≈ 127.505
    @test by_name["g1"].initial_status == 24
    @test by_name["g2"].initial_power ≈ 0.0
    @test by_name["g2"].initial_status == 24
    @test by_name["g3"].initial_power ≈ 100.0
    @test by_name["g3"].initial_status == 24
    @test by_name["g4"].initial_power ≈ 33.0
    @test by_name["g4"].initial_status == 24
    @test by_name["g5"].initial_power ≈ 0.0
    @test by_name["g5"].initial_status == -24
    @test by_name["g6"].initial_power ≈ 0.0
    @test by_name["g6"].initial_status == -24
end
