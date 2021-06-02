# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using UnitCommitment
import UnitCommitment:
    ArrCon2000,
    CarArr2006,
    DamKucRajAta2016,
    Formulation,
    Gar1962,
    KnuOstWat2018,
    MorLatRam2013,
    PanGua2016

function _test(formulation::Formulation)::Nothing
    instance = UnitCommitment.read_benchmark("matpower/case118/2017-02-01")
    UnitCommitment.build_model(instance = instance, formulation = formulation)  # should not crash
    return
end

@testset "formulations" begin
    _test(Formulation(ramping = ArrCon2000.Ramping()))
    _test(Formulation(ramping = DamKucRajAta2016.Ramping()))
    _test(
        Formulation(
            ramping = MorLatRam2013.Ramping(),
            startup_costs = MorLatRam2013.StartupCosts(),
        ),
    )
    _test(Formulation(ramping = PanGua2016.Ramping()))
    _test(Formulation(pwl_costs = Gar1962.PwlCosts()))
    _test(Formulation(pwl_costs = CarArr2006.PwlCosts()))
    _test(Formulation(pwl_costs = KnuOstWat2018.PwlCosts()))
end
