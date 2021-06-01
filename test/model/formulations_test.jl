# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using UnitCommitment

function _test(formulation::UnitCommitment.Formulation)::Nothing
    instance = UnitCommitment.read_benchmark("matpower/case118/2017-02-01")
    UnitCommitment._build_model(instance, formulation)  # should not crash
    return
end

@testset "formulations" begin
    _test(UnitCommitment.Formulation(ramping = UnitCommitment.ArrCon00()))
    _test(UnitCommitment.Formulation(ramping = UnitCommitment.DamKucRajAta16()))
    _test(UnitCommitment.Formulation(ramping = UnitCommitment.MorLatRam13()))
    _test(UnitCommitment.Formulation(ramping = UnitCommitment.PanGua16()))
end
