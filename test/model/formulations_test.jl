# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using UnitCommitment
using JuMP
using Cbc
using JSON
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

function _small_test(formulation::Formulation; dump::Bool = false)::Nothing
    instance = UnitCommitment.read_benchmark("test/case14")
    model = UnitCommitment.build_model(
        instance = instance,
        formulation = formulation,
        optimizer = Cbc.Optimizer,
        variable_names = true,
    )
    UnitCommitment.optimize!(model)
    solution = UnitCommitment.solution(model)
    if dump
        open("/tmp/ucjl.json", "w") do f
            return write(f, JSON.json(solution, 2))
        end
        write_to_file(model, "/tmp/ucjl.lp")
    end
    @test UnitCommitment.validate(instance, solution)
    return
end

function _large_test(formulation::Formulation)::Nothing
    instance =
        UnitCommitment.read_benchmark("pglib-uc/ca/Scenario400_reserves_1")
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
    return
end

function _test(formulation::Formulation; dump::Bool = false)::Nothing
    _small_test(formulation; dump)
    if ENABLE_LARGE_TESTS
        _large_test(formulation)
    end
end

@testset "formulations" begin
    @testset "default" begin
        _test(Formulation())
    end
    @testset "ArrCon2000" begin
        _test(Formulation(ramping = ArrCon2000.Ramping()))
    end
    @testset "DamKucRajAta2016" begin
        _test(Formulation(ramping = DamKucRajAta2016.Ramping()))
    end
    @testset "MorLatRam2013" begin
        _test(
            Formulation(
                ramping = MorLatRam2013.Ramping(),
                startup_costs = MorLatRam2013.StartupCosts(),
            ),
        )
    end
    @testset "PanGua2016" begin
        _test(Formulation(ramping = PanGua2016.Ramping()))
    end
    @testset "Gar1962" begin
        _test(Formulation(pwl_costs = Gar1962.PwlCosts()))
    end
    @testset "CarArr2006" begin
        _test(Formulation(pwl_costs = CarArr2006.PwlCosts()))
    end
    @testset "KnuOstWat2018" begin
        _test(Formulation(pwl_costs = KnuOstWat2018.PwlCosts()))
    end
end
