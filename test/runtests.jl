# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using Test
using UnitCommitment

push!(Base.LOAD_PATH, @__DIR__)
UnitCommitment._setup_logger(level = Base.CoreLogging.Error)

FIXTURES = "$(@__DIR__)/fixtures"

@testset "UnitCommitment" begin
    include("usage.jl")
    @testset "import" begin
        include("import/egret_test.jl")
    end
    @testset "instance" begin
        include("instance/read_test.jl")
        include("instance/migrate_test.jl")
    end
    @testset "model" begin
        include("model/formulations_test.jl")
    end
    @testset "solution" begin
        @testset "XavQiuWanThi19" begin
            include("solution/methods/XavQiuWanThi19/filter_test.jl")
            include("solution/methods/XavQiuWanThi19/find_test.jl")
            include("solution/methods/XavQiuWanThi19/sensitivity_test.jl")
        end
    end
    @testset "transform" begin
        include("transform/initcond_test.jl")
        include("transform/slice_test.jl")
        @testset "randomize" begin
            include("transform/randomize/XavQiuAhm2021_test.jl")
        end
    end
    @testset "validation" begin
        include("validation/repair_test.jl")
    end
    @testset "lmp" begin
        include("lmp/conventional_test.jl")
        include("lmp/aelmp_test.jl")
    end
end
