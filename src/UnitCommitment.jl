# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

module UnitCommitment

using Base: String
using DataStructures

include("instance/structs.jl")
include("core/structs.jl")

include("ext/lmp/structs.jl")
include("ext/profiled/structs.jl")
include("ext/psload/structs.jl")
include("ext/storage/structs.jl")
include("ext/thermal/structs.jl")
include("solution/structs.jl")

include("market/structs.jl")
include("ext/thermal/KnuOstWat2018/structs.jl")
include("ext/thermal/MorLatRam2013/structs.jl")

# include("model/formulations/DamKucRajAta2016/structs.jl")
# include("model/formulations/PanGua2016/structs.jl")
# include("solution/methods/XavQiuWanThi2019/structs.jl")
# include("solution/methods/ProgressiveHedging/structs.jl")
# include("model/formulations/WanHob2016/structs.jl")
# include("solution/methods/TimeDecomposition/structs.jl")

# include("market/market.jl")
# include("model/formulations/DamKucRajAta2016/ramp.jl")
# include("model/formulations/MorLatRam2013/scosts.jl")
# include("model/formulations/PanGua2016/ramp.jl")
# include("model/formulations/WanHob2016/ramp.jl")
# include("solution/methods/ProgressiveHedging/optimize.jl")
# include("solution/methods/ProgressiveHedging/read.jl")
# include("solution/methods/ProgressiveHedging/solution.jl")
# include("solution/methods/TimeDecomposition/optimize.jl")
# include("solution/methods/XavQiuWanThi2019/enforce.jl")
# include("solution/methods/XavQiuWanThi2019/filter.jl")
# include("solution/methods/XavQiuWanThi2019/find.jl")
# include("solution/methods/XavQiuWanThi2019/optimize.jl")
# include("solution/optimize.jl")
# include("solution/solution.jl")
# include("solution/write.jl")
# include("transform/initcond.jl")
# include("transform/randomize/XavQiuAhm2021.jl")
# include("transform/slice.jl")

include("core/ext.jl")
include("core/util.jl")
include("ext/lmp/aelmp.jl")
include("ext/lmp/conventional.jl")
include("ext/profiled/profiled.jl")
include("ext/psload/psload.jl")
include("ext/storage/build.jl")
include("ext/storage/read.jl")
include("ext/storage/slice.jl")
include("ext/storage/solution.jl")
include("ext/storage/summarize.jl")
include("ext/storage/validate.jl")
include("ext/thermal/build.jl")
include("ext/thermal/KnuOstWat2018/pwlcosts.jl")
include("ext/thermal/MorLatRam2013/ramp.jl")
include("ext/thermal/MorLatRam2013/slimits.jl")
include("ext/thermal/read.jl")
include("ext/thermal/repair.jl")
include("ext/thermal/slice.jl")
include("ext/thermal/solution.jl")
include("ext/thermal/summarize.jl")
include("ext/thermal/validate.jl")
include("instance/migrate.jl")
include("instance/read.jl")
include("market/market.jl")
include("model/base/bus.jl")
include("model/build.jl")
include("model/jumpext.jl")
include("validation/repair.jl")
include("validation/validate.jl")

end
