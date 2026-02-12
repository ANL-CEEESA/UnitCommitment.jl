# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

module UnitCommitment

using DataStructures
using JuMP
import JuMP: optimize!
using Printf

using Base: String

include("components/bus/structs.jl")

include("structs.jl")

include("lmp/structs.jl")
include("components/profiled/structs.jl")
include("components/psload/structs.jl")
include("components/storage/structs.jl")
include("components/thermal/structs.jl")
include("transmission/phaseangle/structs.jl")
include("transmission/shiftfactors/structs.jl")

# include("methods/ProgressiveHedging/structs.jl")
# include("model/formulations/DamKucRajAta2016/structs.jl")
# include("model/formulations/PanGua2016/structs.jl")
# include("model/formulations/WanHob2016/structs.jl")
include("components/thermal/KnuOstWat2018/structs.jl")
include("components/thermal/MorLatRam2013/structs.jl")
include("market/structs.jl")
include("methods/TimeDecomposition/structs.jl")
include("methods/XavQiuWanThi2019/structs.jl")

# include("market/market.jl")
# include("methods/ProgressiveHedging/optimize.jl")
# include("methods/ProgressiveHedging/read.jl")
# include("methods/ProgressiveHedging/solution.jl")
# include("model/formulations/DamKucRajAta2016/ramp.jl")
# include("model/formulations/MorLatRam2013/scosts.jl")
# include("model/formulations/PanGua2016/ramp.jl")
# include("model/formulations/WanHob2016/ramp.jl")
include("build.jl")
include("components/bus/build.jl")
include("components/bus/read.jl")
include("components/bus/solution.jl")
include("components/bus/summarize.jl")
include("components/profiled/profiled.jl")
include("components/psload/psload.jl")
include("components/storage/build.jl")
include("components/storage/read.jl")
include("components/storage/slice.jl")
include("components/storage/solution.jl")
include("components/storage/summarize.jl")
include("components/storage/validate.jl")
include("components/thermal/build.jl")
include("components/thermal/KnuOstWat2018/pwlcosts.jl")
include("components/thermal/MorLatRam2013/ramp.jl")
include("components/thermal/MorLatRam2013/slimits.jl")
include("components/thermal/read.jl")
include("components/thermal/repair.jl")
include("components/thermal/slice.jl")
include("components/thermal/solution.jl")
include("components/thermal/summarize.jl")
include("components/thermal/validate.jl")
include("ext.jl")
include("lmp/aelmp.jl")
include("lmp/conventional.jl")
include("market/market.jl")
include("methods/TimeDecomposition/optimize.jl")
include("methods/XavQiuWanThi2019/enforce.jl")
include("methods/XavQiuWanThi2019/filter.jl")
include("methods/XavQiuWanThi2019/find.jl")
include("methods/XavQiuWanThi2019/optimize.jl")
include("migrate.jl")
include("optimize.jl")
include("read.jl")
include("repair.jl")
include("solution.jl")
include("transform/initcond.jl")
include("transform/randomize/XavQiuAhm2021.jl")
include("transform/slice.jl")
include("transmission/phaseangle/build.jl")
include("transmission/phaseangle/read.jl")
include("transmission/phaseangle/slice.jl")
include("transmission/phaseangle/solution.jl")
include("transmission/phaseangle/summarize.jl")
include("transmission/shiftfactors/build.jl")
include("transmission/shiftfactors/read.jl")
include("transmission/shiftfactors/sensitivity.jl")
include("transmission/shiftfactors/slice.jl")
include("transmission/shiftfactors/solution.jl")
include("util.jl")
include("validate.jl")
include("write.jl")

end
