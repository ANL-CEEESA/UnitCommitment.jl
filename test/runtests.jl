# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using Test
using UnitCommitment

UnitCommitment._setup_logger()

@testset "UnitCommitment" begin
    include("usage.jl")
    @testset "import" begin
        include("import/egret_test.jl")
    end
    @testset "instance" begin
        include("instance/read_test.jl")
    end
    @testset "model" begin
        include("model/formulations_test.jl")
    end
    @testset "XavQiuWanThi19" begin
        include("solution/methods/XavQiuWanThi19/filter_test.jl")
        include("solution/methods/XavQiuWanThi19/find_test.jl")
        include("solution/methods/XavQiuWanThi19/sensitivity_test.jl")
    end
    @testset "transform" begin
        include("transform/initcond_test.jl")
        include("transform/slice_test.jl")
    end
    @testset "validation" begin
        include("validation/repair_test.jl")
    end
end
