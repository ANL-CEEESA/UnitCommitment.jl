# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using UnitCommitment
using JuMP
import UnitCommitment:
    ArrCon2000,
    CarArr2006,
    DamKucRajAta2016,
    Formulation,
    Gar1962,
    KnuOstWat2018,
    MorLatRam2013,
    PanGua2016,
    XavQiuWanThi2019

if ENABLE_LARGE_TESTS
    using Gurobi
end

function _small_test(formulation::Formulation)::Nothing
    instances = ["matpower/case118/2017-02-01", "test/case14"]
    for instance in instances
        # Should not crash
        @show "$(instance)"
        UnitCommitment.build_model(
            instance = UnitCommitment.read_benchmark(instance),
            formulation = formulation,
        )
    end
    return
end

function _large_test(formulation::Formulation)::Nothing
    instances = ["pglib-uc/ca/Scenario400_reserves_1"]
    for instance in instances
        instance = UnitCommitment.read_benchmark(instance)
        model = UnitCommitment.build_model(
            instance = instance,
            formulation = formulation,
            optimizer = Gurobi.Optimizer,
        )
        UnitCommitment.optimize!(
            model,
            XavQiuWanThi2019.Method(two_phase_gap = false, gap_limit = 0.1),
        )
        solution = UnitCommitment.solution(model)
        @test UnitCommitment.validate(instance, solution)
    end
    return
end

function _test(formulation::Formulation)::Nothing
    _small_test(formulation)
    if ENABLE_LARGE_TESTS
        _large_test(formulation)
    end
end

@testset "formulations" begin
    @show "testset formulations"
    _test(Formulation())
    @show "ArrCon2000 ramping"
    _test(Formulation(ramping = ArrCon2000.Ramping()))

    # _test(Formulation(ramping = DamKucRajAta2016.Ramping()))
    @show "MorLatRam2013 ramping"
    _test(
        Formulation(
            ramping = MorLatRam2013.Ramping(),
            startup_costs = MorLatRam2013.StartupCosts(),
        ),
    )
    @show "PanGua2016 ramping"
    _test(Formulation(ramping = PanGua2016.Ramping()))
    @show "Gar1962 PwlCosts"
    _test(Formulation(pwl_costs = Gar1962.PwlCosts()))
    @show "CarArr2006 PwlCosts"
    _test(Formulation(pwl_costs = CarArr2006.PwlCosts()))
    @show "KnuOstWat2018 PwlCosts"
    _test(Formulation(pwl_costs = KnuOstWat2018.PwlCosts()))
    @show "formulations completed"
end
