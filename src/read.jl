# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using Printf
using JSON
using DataStructures
using CodecZlib
import Base: getindex, time

const INSTANCES_URL = "https://axavier.org/UnitCommitment.jl/0.4/instances"

const DEFAULT_EXTENSIONS = [
    ThermalExt(),
    ProfiledUnitsExt(),
    PriceSensitiveLoadsExt(),
    VirtualTransactionsExt(),
    StorageExt(),
    ShiftFactorsTransmissionExt(),
    InterfaceLimitsExt(),
    ConventionalLMP(),
]

"""
    read_benchmark(name; quiet=false, extensions=[])::UnitCommitmentInstance

Read a benchmark instance by name. If the instance is not cached locally, it is
downloaded from the instance repository and stored for future use. See
[Instances](guides/instances.md) for the list of available benchmarks.

# Arguments
- `name::AbstractString`: benchmark path (e.g. `"matpower/case3375wp/2017-02-01"`).
- `quiet::Bool`: suppress download and citation messages.
- `extensions::Vector`: extensions to activate when reading the instance.

# Example
```julia
instance = UnitCommitment.read_benchmark("matpower/case3375wp/2017-02-01")
```
"""
function read_benchmark(
    name::AbstractString;
    quiet::Bool = false,
    extensions::Vector = [],
)::UnitCommitmentInstance
    basedir = dirname(@__FILE__)
    filename = "$basedir/../../instances/$name.json.gz"
    url = "$INSTANCES_URL/$name.json.gz"
    if !isfile(filename)
        quiet || @info "Downloading: $(url)"
        mkpath(dirname(filename))
        cp(download(url), filename)
        json = _parse_json_file(filename)
        if !quiet && haskey(json, "SOURCE")
            @info "If you use this instance in your research, please cite:\n\n$(json["SOURCE"])\n"
        end
    end
    return UnitCommitment.read(filename; extensions)
end

"""
    read(path; extensions=[], repair=true)::UnitCommitmentInstance

Read a deterministic unit commitment instance from a JSON file (optionally
gzipped). The resulting instance contains a single scenario named `"s1"` with
probability 1.

# Arguments
- `path::String`: path to a `.json` or `.json.gz` file.
- `extensions::Vector`: extensions to activate when reading the instance.
- `repair::Bool`: if `true`, call `repair!` to fix common data issues.

# Example

```julia
instance = UnitCommitment.read("case118.json.gz")
```
"""
function read(
    path::String;
    extensions::Vector = [],
    repair::Bool = true,
)::UnitCommitmentInstance
    extensions = _merge_extensions(extensions)
    scenario = _read_scenario(path, extensions)
    scenario.name = "s1"
    scenario[:probability] = 1.0
    instance = UnitCommitmentInstance(
        time = scenario[:time];
        scenarios = [scenario],
        extensions,
        extension_by_slot = _build_extension_by_slot(extensions),
    )
    repair && repair!(instance)
    return instance
end

"""
    read(paths; extensions=[], repair=true)::UnitCommitmentInstance

Read a stochastic unit commitment instance from multiple JSON files (optionally
gzipped). Each file describes one scenario. Scenario names are derived from the
file names and probabilities are normalized to sum to 1.

# Arguments
- `paths::Vector{String}`: paths to `.json` or `.json.gz` files.
- `extensions::Vector`: extensions to activate when reading the instance.
- `repair::Bool`: if `true`, call `repair!` to fix common data issues.

# Example

```julia
instance = UnitCommitment.read(["s1.json.gz", "s2.json.gz"])
```
"""
function read(
    paths::Vector{String};
    extensions::Vector = [],
    repair::Bool = true,
)::UnitCommitmentInstance
    extensions = _merge_extensions(extensions)
    scenarios = [_read_scenario(p, extensions) for p in paths]
    _assign_scenario_names!(scenarios, paths)
    _normalize_probabilities!(scenarios)
    instance = UnitCommitmentInstance(
        time = scenarios[1][:time];
        scenarios,
        extensions,
        extension_by_slot = _build_extension_by_slot(extensions),
    )
    repair && repair!(instance)
    return instance
end

# --- Internal helpers --------------------------------------------------------

function _merge_extensions(user_extensions)
    merged = deepcopy(DEFAULT_EXTENSIONS)
    for ext in user_extensions
        slot = extension_slot(ext)
        idx = if slot !== nothing
            findfirst(d -> extension_slot(d) == slot, merged)
        else
            findfirst(d -> typeof(d) == typeof(ext), merged)
        end
        if idx !== nothing
            merged[idx] = ext   # override default (same slot or same type)
        else
            push!(merged, ext)  # add new extension
        end
    end
    return merged
end

function _build_extension_by_slot(extensions)
    return Dict(
        extension_slot(ext) => ext for
        ext in extensions if extension_slot(ext) !== nothing
    )
end

function _parse_json_file(path::String)
    opener = endswith(path, ".gz") ? CodecZlib.GzipDecompressorStream : identity
    Base.open(path, "r") do raw
        io = opener === identity ? raw : opener(raw)
        return JSON.parse(io, dicttype = () -> DefaultOrderedDict(nothing))
    end
end

function _read_scenario(
    path::String,
    extensions::Vector,
)::UnitCommitmentScenario
    json = _parse_json_file(path)
    _migrate(json)
    params = json["Parameters"]

    T = _parse_time(params)
    scenario =
        UnitCommitmentScenario(name = something(params["Scenario name"], ""))
    scenario[:time] = T
    scenario[:time_step] = to_scalar(params["Time step (min)"], default = 60)
    scenario[:probability] = something(params["Scenario weight"], 1)
    scenario[:investment_cost_weight] =
        something(params["Investment cost weight"], 1.0)
    scenario[:power_balance_penalty] = to_timeseries(
        params["Power balance penalty (\$/MW)"],
        T,
        default = fill(1000.0, T),
    )
    scenario[:base_mva] = to_scalar(params["Base MVA"], default = 100.0)

    _read_buses!(json, scenario)
    for ext in extensions
        read_json(json, scenario, ext)
    end
    return scenario
end

function _parse_time(params)::Int
    time_horizon = params["Time horizon (min)"]
    if time_horizon === nothing
        time_horizon =
            something(params["Time (h)"], params["Time horizon (h)"], nothing)
        time_horizon !== nothing && (time_horizon *= 60)
    end
    time_horizon !== nothing || error("Missing parameter: Time horizon (min)")
    isinteger(time_horizon) ||
        error("Time horizon must be an integer in minutes")
    time_horizon = Int(time_horizon)
    time_step = to_scalar(params["Time step (min)"], default = 60)
    60 % time_step == 0 || error("Time step $time_step is not a divisor of 60")
    time_horizon % time_step == 0 || error(
        "Time step $time_step is not a divisor of time horizon $time_horizon",
    )
    return time_horizon ÷ time_step
end

function _assign_scenario_names!(
    scenarios::Vector{UnitCommitmentScenario},
    paths::Vector{String},
)::Nothing
    counts = Dict{String,Int}()
    for (path, sc) in zip(paths, scenarios)
        base = sc.name == "" ? first(split(basename(path), ".")) : sc.name
        k = get(counts, base, 0)
        counts[base] = k + 1
        sc.name = k == 0 ? base : "$(base)_$k"
    end
    return
end

function _normalize_probabilities!(
    scenarios::Vector{UnitCommitmentScenario},
)::Nothing
    total = sum(sc[:probability] for sc in scenarios)
    for sc in scenarios
        sc[:probability] /= total
    end
    return
end
