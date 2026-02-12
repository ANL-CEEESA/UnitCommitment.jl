module UnitCommitmentT

using HiGHS
using JuliaFormatter
using JuMP
using Logging
using Test
using UnitCommitment

include("util.jl")

# include("market/market_test.jl")
# include("solution/methods/ProgressiveHedging/usage_test.jl")
include("solution/methods/TimeDecomposition/initial_status_test.jl")
include("solution/methods/TimeDecomposition/optimize_test.jl")
include("solution/methods/TimeDecomposition/update_solution_test.jl")
include("transform/initcond_test.jl")
include("transform/randomize/XavQiuAhm2021_test.jl")
include("components/bus/build_test.jl")
include("components/bus/read_test.jl")
include("components/profiled/build_test.jl")
include("components/profiled/read_test.jl")
include("components/profiled/slice_test.jl")
include("components/psload/build_test.jl")
include("components/psload/read_test.jl")
include("components/psload/slice_test.jl")
include("components/storage/build_test.jl")
include("components/storage/read_test.jl")
include("components/storage/slice_test.jl")
include("components/thermal/build_test.jl")
include("components/thermal/read_test.jl")
include("components/thermal/repair_test.jl")
include("components/thermal/slice_test.jl")
include("lmp/aelmp_test.jl")
include("lmp/conventional_test.jl")
include("migrate_test.jl")
include("model/model_KnuOstWat2018_test.jl")
include("model/model_MorLatRam2013_test.jl")
include("regression.jl")
include("solution/methods/XavQiuWanThi19/filter_test.jl")
include("solution/methods/XavQiuWanThi19/find_test.jl")
include("solution/methods/XavQiuWanThi19/sensitivity_test.jl")
include("transmission/phaseangle/build_test.jl")
include("transmission/phaseangle/flow_test.jl")
include("transmission/phaseangle/read_test.jl")
include("transmission/phaseangle/slice_test.jl")
include("transmission/shiftfactors/build_test.jl")
include("transmission/shiftfactors/flow_test.jl")
include("transmission/shiftfactors/sensitivity_test.jl")
include("transform/slice_test.jl")
include("usage_test.jl")

function runtests()
    original_logger = global_logger()
    global_logger(ConsoleLogger(stderr, Logging.Info))
    try
        @testset "UnitCommitment" begin
            for sym in sort(names(UnitCommitmentT))
                endswith(string(sym), "_test") || continue
                getfield(UnitCommitmentT, sym)()
            end
        end
    finally
        global_logger(original_logger)
    end
    return
end

function format()
    JuliaFormatter.format(basedir, verbose = true)
    JuliaFormatter.format("$basedir/../../src", verbose = true)
    JuliaFormatter.format("$basedir/../../docs/src", verbose = true)
    return
end

export runtests, format

end # module UnitCommitmentT
