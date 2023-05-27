# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using UnitCommitment, Test, LinearAlgebra
import UnitCommitment: _Violation, _offer, _query

function solution_methods_XavQiuWanThi19_filter_test()
    @testset "_ViolationFilter" begin
        instance = UnitCommitment.read(fixture("case14.json.gz"))
        sc = instance.scenarios[1]
        filter =
            UnitCommitment._ViolationFilter(max_per_line = 1, max_total = 2)
        _offer(
            filter,
            _Violation(
                time = 1,
                monitored_line = sc.lines[1],
                outage_line = nothing,
                amount = 100.0,
            ),
        )
        _offer(
            filter,
            _Violation(
                time = 1,
                monitored_line = sc.lines[1],
                outage_line = sc.lines[1],
                amount = 300.0,
            ),
        )
        _offer(
            filter,
            _Violation(
                time = 1,
                monitored_line = sc.lines[1],
                outage_line = sc.lines[5],
                amount = 500.0,
            ),
        )
        _offer(
            filter,
            _Violation(
                time = 1,
                monitored_line = sc.lines[1],
                outage_line = sc.lines[4],
                amount = 400.0,
            ),
        )
        _offer(
            filter,
            _Violation(
                time = 1,
                monitored_line = sc.lines[2],
                outage_line = sc.lines[1],
                amount = 200.0,
            ),
        )
        _offer(
            filter,
            _Violation(
                time = 1,
                monitored_line = sc.lines[2],
                outage_line = sc.lines[8],
                amount = 100.0,
            ),
        )

        actual = _query(filter)
        expected = [
            _Violation(
                time = 1,
                monitored_line = sc.lines[2],
                outage_line = sc.lines[1],
                amount = 200.0,
            ),
            _Violation(
                time = 1,
                monitored_line = sc.lines[1],
                outage_line = sc.lines[5],
                amount = 500.0,
            ),
        ]
        @test actual == expected
    end
end
