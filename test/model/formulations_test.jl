# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using UnitCommitment
using JuMP
using Cbc
import UnitCommitment:
    ArrCon2000,
    CarArr2006,
    DamKucRajAta2016,
    Formulation,
    Gar1962,
    KnuOstWat2018,
    MorLatRam2013,
    PanGua2016,
    XavQiuWanThi2019,
    WanHob2016

function _test(
    formulation::Formulation;
    instances::Array{String} = ["test/case14"],
    optimizer = optimizer_with_attributes(Cbc.Optimizer, "logLevel" => 0),
)::Nothing
    for instance_name in instances
        instance = UnitCommitment.read_benchmark(instance_name)
        model = UnitCommitment.build_model(
            instance = instance,
            formulation = formulation,
            optimizer = optimizer,
        )
        UnitCommitment.optimize!(
            model,
            XavQiuWanThi2019.Method(two_phase_gap = false, gap_limit = 0.1),
        )
        solution = UnitCommitment.solution(model)
        @test UnitCommitment.validate(instance, solution)
    end
end

@testset "formulations" begin
    _test(Formulation())
    _test(Formulation(ramping = ArrCon2000.Ramping()))

    # _test(Formulation(ramping = DamKucRajAta2016.Ramping()))
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
    _test(
        Formulation(ramping = WanHob2016.Ramping()),
        instances = ["test/case14-flex"],
    )
end
