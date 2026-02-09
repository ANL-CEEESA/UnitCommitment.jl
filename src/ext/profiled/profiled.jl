# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using JuMP
using Printf

function read_json(
    json::AbstractDict,
    sc::UnitCommitmentScenario,
    ::ProfiledUnitsExt,
)
    T = sc.time
    profiled_units = ProfiledUnit[]

    if "Generators" in keys(json)
        for (unit_name, dict) in json["Generators"]
            unit_type = dict["Type"]
            unit_type !== nothing || continue
            lowercase(unit_type) === "profiled" || continue

            bus = sc.buses_by_name[dict["Bus"]]
            pu = ProfiledUnit(
                name = unit_name,
                bus = bus,
                min_power = to_timeseries(
                    dict["Minimum power (MW)"] !== nothing ?
                    dict["Minimum power (MW)"] : 0.0,
                    T,
                ),
                max_power = to_timeseries(dict["Maximum power (MW)"], T),
                cost = to_timeseries(dict["Cost (\$/MW)"], T),
                invest = to_timeseries(
                    dict["Investment cost (\$)"] !== nothing ?
                    dict["Investment cost (\$)"] : 0.0,
                    T,
                ),
            )
            push!(profiled_units, pu)
        end
    end

    sc.data[:profiled] = profiled_units
    sc.data[:profiled_by_name] = Dict(pu.name => pu for pu in profiled_units)
    return
end

function build_model(
    model::JuMP.Model,
    instance::UnitCommitmentInstance,
    ::ProfiledUnitsExt,
)::Nothing
    T = instance.time
    prod = _init(model, :prod)
    invest = _init(model, :invest)

    # Production variables
    for sc in instance.scenarios
        for pu in sc.data[:profiled], t in 1:T
            prod[sc.name, pu.name, t] = @variable(
                model,
                lower_bound = pu.min_power[t],
                upper_bound = pu.max_power[t],
            )
            add_to_expression!(
                model[:net_injection][sc.name, pu.bus.name, t],
                prod[sc.name, pu.name, t],
                1.0,
            )
        end
    end

    # Investment variables
    for pu in instance.scenarios[1].data[:profiled]
        pu.invest[1] > 0.0 || continue
        invest[pu.name, 0] = 0.0
        for t in 1:T
            invest[pu.name, t] = @variable(model, binary = true)
        end
    end

    # Production costs
    for t in 1:T, sc in instance.scenarios
        for pu in sc.data[:profiled]
            add_to_expression!(
                model[:obj],
                prod[sc.name, pu.name, t],
                pu.cost[t] * sc.probability,
            )
        end
    end

    # Investment costs
    for pu in instance.scenarios[1].data[:profiled]
        pu.invest[1] > 0.0 || continue
        for t in 1:T
            add_to_expression!(
                model[:obj],
                invest[pu.name, t] - invest[pu.name, t-1],
                pu.invest[t] * instance.scenarios[1].investment_cost_weight,
            )
        end
    end

    # Unit is permanently built once invested
    eq_invest_nondec = _init(model, :eq_invest_nondec)
    for pu in instance.scenarios[1].data[:profiled]
        pu.invest[1] > 0.0 || continue
        for t in 2:T
            eq_invest_nondec[pu.name, t] =
                @constraint(model, invest[pu.name, t-1] <= invest[pu.name, t],)
        end
    end

    # Unit generation bounds are zero if not invested
    eq_invest_prod_ub = _init(model, :eq_invest_prod_ub)
    eq_invest_prod_lb = _init(model, :eq_invest_prod_lb)
    for sc in instance.scenarios
        for pu in sc.data[:profiled]
            pu.invest[1] > 0.0 || continue
            for t in 1:T
                eq_invest_prod_ub[sc.name, pu.name, t] = @constraint(
                    model,
                    prod[sc.name, pu.name, t] <=
                    pu.max_power[t] * invest[pu.name, t],
                )
                eq_invest_prod_lb[sc.name, pu.name, t] = @constraint(
                    model,
                    prod[sc.name, pu.name, t] >=
                    pu.min_power[t] * invest[pu.name, t],
                )
            end
        end
    end

    return
end

function store_solution(
    sol::AbstractDict,
    model::JuMP.Model,
    ::ProfiledUnitsExt,
)::Nothing
    instance = model[:instance]
    T = instance.time
    for sc in instance.scenarios
        profiled_units = sc.data[:profiled]

        sol[sc.name]["Profiled: Production (MW)"] =
            _timeseries(model, :prod, profiled_units, T, sc = sc)

        sol[sc.name]["Profiled: Utilization (%)"] = OrderedDict(
            pu.name => [
                round(
                    100.0 * value(model[:prod][sc.name, pu.name, t]) /
                    pu.max_power[t],
                    digits = 2,
                ) for t in 1:T
            ] for pu in profiled_units
        )

        sol[sc.name]["Profiled: Production cost (\$)"] = OrderedDict(
            pu.name => [
                value(model[:prod][sc.name, pu.name, t]) * pu.cost[t]
                for t in 1:T
            ] for pu in profiled_units
        )

        sol[sc.name]["Profiled: Investment status"] = OrderedDict(
            pu.name => [value(model[:invest][pu.name, t]) for t in 1:T] for
            pu in profiled_units if pu.invest[1] > 0.0
        )
    end

    return
end

function validate!(
    instance::UnitCommitmentInstance,
    solution::AbstractDict,
    ::ProfiledUnitsExt;
    tol = 0.01,
)::Int
    err_count = 0

    for sc in instance.scenarios, pu in sc.data[:profiled]
        production = solution[sc.name]["Profiled: Production (MW)"][pu.name]
        for t in 1:instance.time
            # Unit must produce at least its minimum power
            if production[t] < pu.min_power[t] - tol
                @error @sprintf(
                    "Profiled unit %s produces below its minimum limit at time %d (%.2f < %.2f)",
                    pu.name,
                    t,
                    production[t],
                    pu.min_power[t]
                )
                err_count += 1
            end

            # Unit must produce at most its maximum power
            if production[t] > pu.max_power[t] + tol
                @error @sprintf(
                    "Profiled unit %s produces above its maximum limit at time %d (%.2f > %.2f)",
                    pu.name,
                    t,
                    production[t],
                    pu.max_power[t]
                )
                err_count += 1
            end
        end
    end

    return err_count
end

function summarize(
    instance::UnitCommitmentInstance,
    ::ProfiledUnitsExt,
    io::IO,
)::Nothing
    count = length(instance.scenarios[1].data[:profiled])
    print(io, "$count profiled units, ")
    return
end

function slice!(
    sc::UnitCommitmentScenario,
    range::UnitRange{Int},
    ::ProfiledUnitsExt,
)::Nothing
    for pu in sc.data[:profiled]
        pu.max_power = pu.max_power[range]
        pu.min_power = pu.min_power[range]
        pu.cost = pu.cost[range]
        pu.invest = pu.invest[range]
    end
    return
end
