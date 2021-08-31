# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

doc = """UnitCommitment.jl Benchmark Runner

Usage:
  run.jl [-s ARG]... [-m ARG]... [-c ARG]... [-f ARG]... [options]

Examples:

    1. Benchmark all solvers, methods and formulations:

        julia run.jl

    2. Benchmark formulations "default" and "ArrCon200" using Gurobi:

        julia run.jl -s gurobi -f default -f ArrCon2000

    3. Benchmark a few test cases, using all solvers, methods and formulations:

        julia run.jl -c or-lib/20_0_1_w -c matpower/case1888rte/2017-02-01

    4. Solve 4 test cases in parallel, with 2 threads available per worker:

        JULIA_NUM_THREADS=2 julia --procs 4 run.jl

Options:
  -h --help             Show this screen.
  -s --solver=ARG       Mixed-integer linear solver (e.g. gurobi)
  -c --case=ARG         Unit commitment test case (e.g. or-lib/20_0_1_w)
  -m --method=ARG       Solution method (e.g. default)
  -f --formulation=ARG  Formulation (e.g. ArrCon2000)
  --time-limit=ARG      Time limit in seconds [default: 3600]
  --gap=ARG             Relative MIP gap tolerance [default: 0.001]
  --trials=ARG          Number of trials [default: 5]
"""

using Distributed
using Pkg
Pkg.activate(".")
@everywhere using Pkg
@everywhere Pkg.activate(".")

using DocOpt
args = docopt(doc)

@everywhere using UnitCommitment
@everywhere UnitCommitment._setup_logger()

using UnitCommitment
using Gurobi
using Logging
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

# Benchmark test cases
# -----------------------------------------------------------------------------
cases = [
    "pglib-uc/ca/2014-09-01_reserves_0",
    "pglib-uc/ca/2014-09-01_reserves_1",
    "pglib-uc/ca/2015-03-01_reserves_0",
    "pglib-uc/ca/2015-06-01_reserves_0",
    "pglib-uc/ca/Scenario400_reserves_1",
    "pglib-uc/ferc/2015-01-01_lw",
    "pglib-uc/ferc/2015-05-01_lw",
    "pglib-uc/ferc/2015-07-01_hw",
    "pglib-uc/ferc/2015-10-01_lw",
    "pglib-uc/ferc/2015-12-01_lw",
    "pglib-uc/rts_gmlc/2020-04-03",
    "pglib-uc/rts_gmlc/2020-09-20",
    "pglib-uc/rts_gmlc/2020-10-27",
    "pglib-uc/rts_gmlc/2020-11-25",
    "pglib-uc/rts_gmlc/2020-12-23",
    "or-lib/20_0_1_w",
    "or-lib/20_0_5_w",
    "or-lib/50_0_2_w",
    "or-lib/75_0_2_w",
    "or-lib/100_0_1_w",
    "or-lib/100_0_4_w",
    "or-lib/100_0_5_w",
    "or-lib/200_0_3_w",
    "or-lib/200_0_7_w",
    "or-lib/200_0_9_w",
    "tejada19/UC_24h_290g",
    "tejada19/UC_24h_623g",
    "tejada19/UC_24h_959g",
    "tejada19/UC_24h_1577g",
    "tejada19/UC_24h_1888g",
    "tejada19/UC_168h_72g",
    "tejada19/UC_168h_86g",
    "tejada19/UC_168h_130g",
    "tejada19/UC_168h_131g",
    "tejada19/UC_168h_199g",
    "matpower/case1888rte/2017-02-01",
    "matpower/case1951rte/2017-02-01",
    "matpower/case2848rte/2017-02-01",
    "matpower/case3012wp/2017-02-01",
    "matpower/case3375wp/2017-02-01",
    "matpower/case6468rte/2017-02-01",
    "matpower/case6515rte/2017-02-01",
]

# Formulations
# -----------------------------------------------------------------------------
formulations = Dict(
    "default" => Formulation(),
    "ArrCon2000" => Formulation(ramping = ArrCon2000.Ramping()),
    "CarArr2006" => Formulation(pwl_costs = CarArr2006.PwlCosts()),
    "DamKucRajAta2016" => Formulation(ramping = DamKucRajAta2016.Ramping()),
    "Gar1962" => Formulation(pwl_costs = Gar1962.PwlCosts()),
    "KnuOstWat2018" => Formulation(pwl_costs = KnuOstWat2018.PwlCosts()),
    "MorLatRam2013" => Formulation(ramping = MorLatRam2013.Ramping()),
    "PanGua2016" => Formulation(ramping = PanGua2016.Ramping()),
)

# Solution methods
# -----------------------------------------------------------------------------
const gap_limit = parse(Float64, args["--gap"])
const time_limit = parse(Float64, args["--time-limit"])
methods = Dict(
    "default" => XavQiuWanThi2019.Method(
        time_limit = time_limit,
        gap_limit = gap_limit,
    ),
)

# MIP solvers
# -----------------------------------------------------------------------------
optimizers = Dict(
    "gurobi" => optimizer_with_attributes(
        Gurobi.Optimizer,
        "Threads" => Threads.nthreads(),
    ),
)

# Parse command line arguments
# -----------------------------------------------------------------------------
if !isempty(args["--case"])
    cases = args["--case"]
end
if !isempty(args["--formulation"])
    formulations = filter(p -> p.first in args["--formulation"], formulations)
end
if !isempty(args["--method"])
    methods = filter(p -> p.first in args["--method"], methods)
end
if !isempty(args["--solver"])
    optimizers = filter(p -> p.first in args["--solver"], optimizers)
end
const ntrials = parse(Int, args["--trials"])

# Print benchmark settings
# -----------------------------------------------------------------------------
function printlist(d::Dict)
    for key in keys(d)
        @info "  - $key"
    end
end

function printlist(d::Vector)
    for key in d
        @info "  - $key"
    end
end

@info "Computational environment:"
@info "  - CPU: $(Sys.cpu_info()[1].model)"
@info "  - Logical CPU cores: $(length(Sys.cpu_info()))"
@info "  - System memory: $(round(Sys.total_memory() / 2^30, digits=2)) GiB"
@info "  - Available workers: $(nworkers())"
@info "  - Available threads per worker: $(Threads.nthreads())"

@info "Parameters:"
@info "  - Number of trials: $ntrials"
@info "  - Time limit (s): $time_limit"
@info "  - Relative MIP gap tolerance: $gap_limit"

@info "Solvers:"
printlist(optimizers)

@info "Methods:"
printlist(methods)

@info "Formulations:"
printlist(formulations)

@info "Cases:"
printlist(cases)

# Run benchmarks
# -----------------------------------------------------------------------------
UnitCommitment._run_benchmarks(
    cases = cases,
    formulations = formulations,
    methods = methods,
    optimizers = optimizers,
    trials = 1:ntrials,
)
