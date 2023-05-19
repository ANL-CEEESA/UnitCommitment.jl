module UnitCommitmentT

using JuliaFormatter
using UnitCommitment
using Test

include("usage.jl")
include("import/egret_test.jl")
include("instance/read_test.jl")
include("instance/migrate_test.jl")
include("model/formulations_test.jl")
include("solution/methods/XavQiuWanThi19/filter_test.jl")
include("solution/methods/XavQiuWanThi19/find_test.jl")
include("solution/methods/XavQiuWanThi19/sensitivity_test.jl")
include("transform/initcond_test.jl")
include("transform/slice_test.jl")
include("transform/randomize/XavQiuAhm2021_test.jl")
include("validation/repair_test.jl")
include("lmp/conventional_test.jl")
include("lmp/aelmp_test.jl")

basedir = dirname(@__FILE__)

function fixture(path::String)::String
    return "$basedir/../fixtures/$path"
end

function runtests()
    println("Running tests...")
    UnitCommitment._setup_logger(level = Base.CoreLogging.Error)
    @testset "UnitCommitment" begin
        usage_test()
        import_egret_test()
        instance_read_test()
        instance_migrate_test()
        model_formulations_test()
        solution_methods_XavQiuWanThi19_filter_test()
        solution_methods_XavQiuWanThi19_find_test()
        solution_methods_XavQiuWanThi19_sensitivity_test()
        transform_initcond_test()
        transform_slice_test()
        transform_randomize_XavQiuAhm2021_test()
        validation_repair_test()
        lmp_conventional_test()
        lmp_aelmp_test()
    end
    return
end

function format()
    JuliaFormatter.format(basedir, verbose = true)
    JuliaFormatter.format("$basedir/../../src", verbose = true)
    return
end

export runtests, format

end # module UnitCommitmentT
