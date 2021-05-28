# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using UnitCommitment, Test, LinearAlgebra
import UnitCommitment: Violation, _offer, _query

@testset "Screening" begin
    @testset "Violation filter" begin
        instance = UnitCommitment.read_benchmark("test/case14")
        filter = UnitCommitment.ViolationFilter(max_per_line = 1, max_total = 2)

        _offer(
            filter,
            Violation(
                time = 1,
                monitored_line = instance.lines[1],
                outage_line = nothing,
                amount = 100.0,
            ),
        )
        _offer(
            filter,
            Violation(
                time = 1,
                monitored_line = instance.lines[1],
                outage_line = instance.lines[1],
                amount = 300.0,
            ),
        )
        _offer(
            filter,
            Violation(
                time = 1,
                monitored_line = instance.lines[1],
                outage_line = instance.lines[5],
                amount = 500.0,
            ),
        )
        _offer(
            filter,
            Violation(
                time = 1,
                monitored_line = instance.lines[1],
                outage_line = instance.lines[4],
                amount = 400.0,
            ),
        )
        _offer(
            filter,
            Violation(
                time = 1,
                monitored_line = instance.lines[2],
                outage_line = instance.lines[1],
                amount = 200.0,
            ),
        )
        _offer(
            filter,
            Violation(
                time = 1,
                monitored_line = instance.lines[2],
                outage_line = instance.lines[8],
                amount = 100.0,
            ),
        )

        actual = _query(filter)
        expected = [
            Violation(
                time = 1,
                monitored_line = instance.lines[2],
                outage_line = instance.lines[1],
                amount = 200.0,
            ),
            Violation(
                time = 1,
                monitored_line = instance.lines[1],
                outage_line = instance.lines[5],
                amount = 500.0,
            ),
        ]
        @test actual == expected
    end

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
        )
        @test length(violations) == 20
    end
end
