# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using UnitCommitment
import UnitCommitment: Formulation

function _test(formulation::Formulation)::Nothing
    instance = UnitCommitment.read_benchmark("matpower/case118/2017-02-01")
    UnitCommitment._build_model(instance, formulation)  # should not crash
    return
end

@testset "formulations" begin
    _test(Formulation(ramping = UnitCommitment.ArrCon2000()))
    _test(Formulation(ramping = UnitCommitment.DamKucRajAta2016()))
    _test(Formulation(ramping = UnitCommitment.MorLatRam2013()))
    _test(Formulation(ramping = UnitCommitment.PanGua2016()))
    _test(Formulation(pwl_costs = UnitCommitment.Gar1962()))
    _test(Formulation(pwl_costs = UnitCommitment.CarArr2006()))
    _test(Formulation(pwl_costs = UnitCommitment.KnuOstWat2018()))
end
