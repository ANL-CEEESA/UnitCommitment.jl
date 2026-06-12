# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using UnitCommitment, Test, LinearAlgebra

@testfunction methods_XavQiuWanThi19_susceptance_matrix_test begin
    instance = UnitCommitment.read(fixture("/case14.json.gz"))
    sc = instance.scenarios[1]
    actual = UnitCommitment._susceptance_matrix(sc[:branches])
    @test size(actual) == (20, 20)
    expected = Diagonal([
        0.29,
        0.08,
        0.09,
        0.1,
        0.1,
        0.1,
        0.41,
        0.08,
        0.03,
        0.07,
        0.09,
        0.07,
        0.13,
        0.1,
        0.16,
        0.21,
        0.06,
        0.09,
        0.09,
        0.05,
    ])
    @test round.(actual, digits = 2) == expected
end

@testfunction methods_XavQiuWanThi19_reduced_incidence_matrix_test begin
    instance = UnitCommitment.read(fixture("/case14.json.gz"))
    sc = instance.scenarios[1]
    actual = UnitCommitment._reduced_incidence_matrix(
        branches = sc[:branches],
        buses = sc[:bus],
    )
    @test size(actual) == (20, 13)
    @test actual[1, 1] == -1.0
    @test actual[3, 1] == 1.0
    @test actual[4, 1] == 1.0
    @test actual[5, 1] == 1.0
    @test actual[3, 2] == -1.0
    @test actual[6, 2] == 1.0
    @test actual[4, 3] == -1.0
    @test actual[6, 3] == -1.0
    @test actual[7, 3] == 1.0
    @test actual[8, 3] == 1.0
    @test actual[9, 3] == 1.0
    @test actual[2, 4] == -1.0
    @test actual[5, 4] == -1.0
    @test actual[7, 4] == -1.0
    @test actual[10, 4] == 1.0
    @test actual[10, 5] == -1.0
    @test actual[11, 5] == 1.0
    @test actual[12, 5] == 1.0
    @test actual[13, 5] == 1.0
    @test actual[8, 6] == -1.0
    @test actual[14, 6] == 1.0
    @test actual[15, 6] == 1.0
    @test actual[14, 7] == -1.0
    @test actual[9, 8] == -1.0
    @test actual[15, 8] == -1.0
    @test actual[16, 8] == 1.0
    @test actual[17, 8] == 1.0
    @test actual[16, 9] == -1.0
    @test actual[18, 9] == 1.0
    @test actual[11, 10] == -1.0
    @test actual[18, 10] == -1.0
    @test actual[12, 11] == -1.0
    @test actual[19, 11] == 1.0
    @test actual[13, 12] == -1.0
    @test actual[19, 12] == -1.0
    @test actual[20, 12] == 1.0
    @test actual[17, 13] == -1.0
    @test actual[20, 13] == -1.0
end

@testfunction methods_XavQiuWanThi19_injection_shift_factors_test begin
    instance = UnitCommitment.read(fixture("/case14.json.gz"))
    sc = instance.scenarios[1]
    actual = UnitCommitment._injection_shift_factors(
        branches = sc[:branches],
        buses = sc[:bus],
    )
    @test size(actual) == (20, 13)
    @test round.(actual, digits = 2) == [
        -0.84 -0.75 -0.67 -0.61 -0.63 -0.66 -0.66 -0.65 -0.65 -0.64 -0.63 -0.63 -0.64
        -0.16 -0.25 -0.33 -0.39 -0.37 -0.34 -0.34 -0.35 -0.35 -0.36 -0.37 -0.37 -0.36
        0.03 -0.53 -0.15 -0.1 -0.12 -0.14 -0.14 -0.14 -0.13 -0.13 -0.12 -0.12 -0.13
        0.06 -0.14 -0.32 -0.22 -0.25 -0.3 -0.3 -0.29 -0.28 -0.27 -0.25 -0.26 -0.27
        0.08 -0.07 -0.2 -0.29 -0.26 -0.22 -0.22 -0.22 -0.23 -0.25 -0.26 -0.26 -0.24
        0.03 0.47 -0.15 -0.1 -0.12 -0.14 -0.14 -0.14 -0.13 -0.13 -0.12 -0.12 -0.13
        0.08 0.31 0.5 -0.3 -0.03 0.36 0.36 0.28 0.23 0.1 -0.0 0.02 0.17
        0.0 0.01 0.02 -0.01 -0.22 -0.63 -0.63 -0.45 -0.41 -0.32 -0.24 -0.25 -0.36
        0.0 0.01 0.01 -0.01 -0.12 -0.17 -0.17 -0.26 -0.24 -0.18 -0.14 -0.14 -0.21
        -0.0 -0.02 -0.03 0.02 -0.66 -0.2 -0.2 -0.29 -0.36 -0.5 -0.63 -0.61 -0.43
        -0.0 -0.01 -0.02 0.01 0.21 -0.12 -0.12 -0.17 -0.28 -0.53 0.18 0.15 -0.03
        -0.0 -0.0 -0.0 0.0 0.03 -0.02 -0.02 -0.03 -0.02 0.01 -0.52 -0.17 -0.09
        -0.0 -0.01 -0.01 0.01 0.11 -0.06 -0.06 -0.09 -0.05 0.02 -0.28 -0.59 -0.31
        -0.0 -0.0 -0.0 -0.0 -0.0 -0.0 -1.0 -0.0 -0.0 -0.0 -0.0 -0.0 0.0
        0.0 0.01 0.02 -0.01 -0.22 0.37 0.37 -0.45 -0.41 -0.32 -0.24 -0.25 -0.36
        0.0 0.01 0.02 -0.01 -0.21 0.12 0.12 0.17 -0.72 -0.47 -0.18 -0.15 0.03
        0.0 0.01 0.01 -0.01 -0.14 0.08 0.08 0.12 0.07 -0.03 -0.2 -0.24 -0.6
        0.0 0.01 0.02 -0.01 -0.21 0.12 0.12 0.17 0.28 -0.47 -0.18 -0.15 0.03
        -0.0 -0.0 -0.0 0.0 0.03 -0.02 -0.02 -0.03 -0.02 0.01 0.48 -0.17 -0.09
        -0.0 -0.01 -0.01 0.01 0.14 -0.08 -0.08 -0.12 -0.07 0.03 0.2 0.24 -0.4
    ]
end

@testfunction methods_XavQiuWanThi19_line_outage_factors_test begin
    instance = UnitCommitment.read(fixture("/case14.json.gz"))
    sc = instance.scenarios[1]
    isf_before = UnitCommitment._injection_shift_factors(
        branches = sc[:branches],
        buses = sc[:bus],
    )
    lodf = UnitCommitment._line_outage_factors(
        branches = sc[:branches],
        buses = sc[:bus],
        isf = isf_before,
    )
    for contingency in sc[:contingencies]
        for lc in contingency.branches
            prev_susceptance = lc.susceptance
            lc.susceptance = 0.0
            isf_after = UnitCommitment._injection_shift_factors(
                branches = sc[:branches],
                buses = sc[:bus],
            )
            lc.susceptance = prev_susceptance
            for lm in sc[:branches]
                expected = isf_after[lm.offset, :]
                actual =
                    isf_before[lm.offset, :] +
                    lodf[lm.offset, lc.offset] * isf_before[lc.offset, :]
                @test norm(expected - actual) < 1e-6
            end
        end
    end
end
