# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using Printf
using JSON
using DataStructures
using CodecZlib
import Base: getindex, time
using SparseArrays

const INSTANCES_URL = "https://axavier.org/UnitCommitment.jl/0.4/instances"

"""
	read_benchmark(name::AbstractString)::UnitCommitmentInstance

Read one of the benchmark instances included in the package. See
[Instances](guides/instances.md) for the entire list of benchmark instances available.

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
        if !quiet
            @info "Downloading: $(url)"
        end
        dpath = download(url)
        mkpath(dirname(filename))
        cp(dpath, filename)
        json = _read_json(filename)
        if "SOURCE" in keys(json) && !quiet
            @info "If you use this instance in your research, please cite:\n\n$(json["SOURCE"])\n"
        end
    end
    return UnitCommitment.read(filename; extensions)
end

function _repair_scenario_names_and_probabilities!(
    scenarios::Vector{UnitCommitmentScenario},
    path::Vector{String},
)::Nothing
    total_weight = sum([sc.probability for sc in scenarios])
    name_counts = Dict{String,Int}()

    for (sc_path, sc) in zip(path, scenarios)
        base =
            sc.name == "" ? first(split(last(split(sc_path, "/")), ".")) :
            sc.name

        k = get(name_counts, base, 0)
        name_counts[base] = k + 1
        sc.name = k == 0 ? base : "$(base)_$k"

        sc.probability = (sc.probability / total_weight)
    end
    return
end

"""
	read(path::AbstractString)::UnitCommitmentInstance

Read a deterministic test case from the given file. The file may be gzipped.

# Example

```julia
instance = UnitCommitment.read("s1.json.gz")
```
"""
function read(
    path::String;
    extensions::Vector = [],
    repair::Bool = true,
)::UnitCommitmentInstance
    scenarios = Vector{UnitCommitmentScenario}()
    scenario = _read_scenario(path, extensions)
    scenario.name = "s1"
    scenario.probability = 1.0
    scenarios = [scenario]
    instance =
        UnitCommitmentInstance(time = scenario.time; scenarios, extensions)
    if repair
        repair!(instance)
    end
    return instance
end

"""
	read(path::Vector{String})::UnitCommitmentInstance

Read a stochastic unit commitment instance from the given files. Each file
describes a scenario. The files may be gzipped.

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
    scenarios = UnitCommitmentScenario[]
    for p in paths
        push!(scenarios, _read_scenario(p, extensions))
    end
    _repair_scenario_names_and_probabilities!(scenarios, paths)
    instance =
        UnitCommitmentInstance(time = scenarios[1].time; scenarios, extensions)
    if repair
        repair!(instance)
    end
    return instance
end

function _open(f::Function, path::String)
    if endswith(path, ".gz")
        return Base.open(f, CodecZlib.GzipDecompressorStream, path, "r")
    else
        return Base.open(f, path, "r")
    end
end

function _read_scenario(
    path::String,
    extensions::Vector = [],
)::UnitCommitmentScenario
    _open(path) do file
        return _read(file, extensions)
    end
end

function _read(file::IO, extensions::Vector = [])::UnitCommitmentScenario
    return _from_json(
        JSON.parse(file, dicttype = () -> DefaultOrderedDict(nothing)),
        extensions,
    )
end

function _read_json(path::String)::OrderedDict
    _open(path) do file
        return JSON.parse(file, dicttype = () -> DefaultOrderedDict(nothing))
    end
end

function _from_json(json, extensions::Vector = [])::UnitCommitmentScenario
    _migrate(json)
    contingencies = Contingency[]
    lines = TransmissionLine[]

    time_horizon = json["Parameters"]["Time horizon (min)"]
    if time_horizon === nothing
        time_horizon = json["Parameters"]["Time (h)"]
        if time_horizon === nothing
            time_horizon = json["Parameters"]["Time horizon (h)"]
        end
        if time_horizon !== nothing
            time_horizon *= 60
        end
    end
    time_horizon !== nothing || error("Missing parameter: Time horizon (min)")
    isinteger(time_horizon) ||
        error("Time horizon must be an integer in minutes")
    time_horizon = Int(time_horizon)
    time_step = to_scalar(json["Parameters"]["Time step (min)"], default = 60)
    (60 % time_step == 0) ||
        error("Time step $time_step is not a divisor of 60")
    (time_horizon % time_step == 0) || error(
        "Time step $time_step is not a divisor of time horizon $time_horizon",
    )
    T = time_horizon ÷ time_step

    probability = json["Parameters"]["Scenario weight"]
    probability !== nothing || (probability = 1)
    scenario_name = json["Parameters"]["Scenario name"]
    scenario_name !== nothing || (scenario_name = "")
    investment_cost_weight = json["Parameters"]["Investment cost weight"]
    investment_cost_weight !== nothing || (investment_cost_weight = 1.0)

    name_to_line = Dict{String,TransmissionLine}()

    # Read parameters
    power_balance_penalty = to_timeseries(
        json["Parameters"]["Power balance penalty (\$/MW)"],
        T,
        default = [1000.0 for t in 1:T],
    )

    # Create minimal scenario to store buses
    scenario = UnitCommitmentScenario(
        name = scenario_name,
        probability = probability,
        contingencies_by_name = Dict{AbstractString,Contingency}(),
        contingencies = Contingency[],
        lines_by_name = Dict{AbstractString,TransmissionLine}(),
        lines = TransmissionLine[],
        investment_cost_weight = investment_cost_weight,
        power_balance_penalty = power_balance_penalty,
        time = T,
        time_step = time_step,
        isf = spzeros(Float64, 0, 0),
        lodf = spzeros(Float64, 0, 0),
    )

    # Read buses
    _read_buses!(json, scenario)

    # Read transmission lines
    if "Transmission lines" in keys(json)
        for (line_name, dict) in json["Transmission lines"]
            line = TransmissionLine(
                line_name,
                length(lines) + 1,
                scenario.data[:bus_by_name][dict["Source bus"]],
                scenario.data[:bus_by_name][dict["Target bus"]],
                to_scalar(dict["Susceptance (S)"]),
                to_timeseries(
                    dict["Normal flow limit (MW)"],
                    T,
                    default = [1e8 for t in 1:T],
                ),
                to_timeseries(
                    dict["Emergency flow limit (MW)"],
                    T,
                    default = [1e8 for t in 1:T],
                ),
                to_timeseries(
                    dict["Flow limit penalty (\$/MW)"],
                    T,
                    default = [5000.0 for t in 1:T],
                ),
                to_timeseries(
                    to_scalar(dict["Investment cost (\$)"], default = 0.0),
                    T,
                ),
                to_scalar(dict["Max number of parallel circuits"], default = 1),
            )
            name_to_line[line_name] = line
            push!(lines, line)
        end
    end

    # Read contingencies
    if "Contingencies" in keys(json)
        for (cont_name, dict) in json["Contingencies"]
            affected_lines = TransmissionLine[]
            if "Affected lines" in keys(dict)
                affected_lines =
                    [name_to_line[l] for l in dict["Affected lines"]]
            end
            if "Affected units" in keys(dict)
                error("Unit contingencies are not currently supported")
            end
            cont = Contingency(cont_name, affected_lines)
            push!(contingencies, cont)
        end
    end

    # Update scenario with contingencies and lines
    scenario.contingencies_by_name = Dict(c.name => c for c in contingencies)
    scenario.contingencies = contingencies
    scenario.lines_by_name = Dict(l.name => l for l in lines)
    scenario.lines = lines
    scenario.isf = spzeros(Float64, length(lines), length(scenario.data[:bus]) - 1)
    scenario.lodf = spzeros(Float64, length(lines), length(lines))

    for ext in extensions
        read_json(json, scenario, ext)
    end

    return scenario
end
