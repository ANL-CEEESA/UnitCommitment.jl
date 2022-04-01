# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using UnitCommitment, Test, LinearAlgebra
import UnitCommitment: _Violation, _offer, _query

@testset "find_violations" begin
    instance = UnitCommitment.read_benchmark("test/case14")
    for line in instance.lines, t in 1:instance.time
        line.normal_flow_limit[t] = 1.0
        line.emergency_flow_limit[t] = 1.0
    end
    isf = UnitCommitment._injection_shift_factors(
        lines = instance.lines,
        buses = instance.buses,
    )
    lodf = UnitCommitment._line_outage_factors(
        lines = instance.lines,
        buses = instance.buses,
        isf = isf,
    )
    inj = [1000.0 for b in 1:13, t in 1:instance.time]
    overflow = [0.0 for l in instance.lines, t in 1:instance.time]
    violations = UnitCommitment._find_violations(
        instance = instance,
        net_injections = inj,
        overflow = overflow,
        isf = isf,
        lodf = lodf,
        max_per_line = 1,
        max_per_period = 5,
    )
    @test length(violations) == 20
end
