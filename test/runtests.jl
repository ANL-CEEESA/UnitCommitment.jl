# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using Test

@testset "UnitCommitment" begin
    include("instance_test.jl")
    include("model_test.jl")
    include("sensitivity_test.jl")
    include("screening_test.jl")
    include("convert_test.jl")
    include("validate_test.jl")
    include("initcond_test.jl")
end
