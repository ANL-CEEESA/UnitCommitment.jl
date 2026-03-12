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
    T = sc[:time]
    profiled_units = ProfiledUnit[]

    if "Generators" in keys(json)
        for (unit_name, dict) in json["Generators"]
            unit_type = dict["Type"]
            unit_type !== nothing || continue
            lowercase(unit_type) === "profiled" || continue

            bus = sc[:bus_by_name][dict["Bus"]]
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
                invest = to_scalar(dict["Investment cost (\$)"], default = 0.0),
                qmin = to_scalar(
                    dict["Reactive power min (MVAr)"],
                    default = 0.0,
                ),
                qmax = to_scalar(
                    dict["Reactive power max (MVAr)"],
                    default = 0.0,
                ),
            )
            push!(profiled_units, pu)
        end
    end

    sc[:profiled] = profiled_units
    sc[:profiled_by_name] = Dict(pu.name => pu for pu in profiled_units)
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
    qg_profiled = _init(model, :qg_profiled)

    # Production variables
    for sc in instance.scenarios
        for pu in sc[:profiled], t in 1:T
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

    # Reactive power variables
    for sc in instance.scenarios
        for pu in sc[:profiled], t in 1:T
            qg_profiled[sc.name, pu.name, t] =
                @variable(model, lower_bound = pu.qmin, upper_bound = pu.qmax,)
            add_to_expression!(
                model[:net_reactive_injection][sc.name, pu.bus.name, t],
                qg_profiled[sc.name, pu.name, t],
                1.0,
            )
        end
    end

    # Investment variables
    for pu in instance.scenarios[1][:profiled]
        pu.invest > 0.0 || continue
        invest[pu.name] = @variable(model, binary = true)
    end

    # Production costs
    for t in 1:T, sc in instance.scenarios
        for pu in sc[:profiled]
            add_to_expression!(
                model[:obj],
                prod[sc.name, pu.name, t],
                pu.cost[t] * sc[:probability],
            )
        end
    end

    # Investment costs
    for pu in instance.scenarios[1][:profiled]
        pu.invest > 0.0 || continue
        add_to_expression!(
            model[:obj],
            invest[pu.name],
            pu.invest * instance.scenarios[1][:investment_cost_weight],
        )
    end

    # Unit generation bounds are zero if not invested
    eq_invest_prod_ub = _init(model, :eq_invest_prod_ub)
    eq_invest_prod_lb = _init(model, :eq_invest_prod_lb)
    for sc in instance.scenarios
        for pu in sc[:profiled]
            pu.invest > 0.0 || continue
            for t in 1:T
                eq_invest_prod_ub[sc.name, pu.name, t] = @constraint(
                    model,
                    prod[sc.name, pu.name, t] <=
                    pu.max_power[t] * invest[pu.name],
                )
                eq_invest_prod_lb[sc.name, pu.name, t] = @constraint(
                    model,
                    prod[sc.name, pu.name, t] >=
                    pu.min_power[t] * invest[pu.name],
                )
            end
        end
    end

    return
end

function store_solution(
    sol::AbstractDict,
    model::UnitCommitmentModel,
    ::ProfiledUnitsExt,
)::Nothing
    instance = model.instance
    inner = model.inner
    T = instance.time
    for sc in instance.scenarios
        sc_sol = sol[sc.name]
        profiled_units = sc[:profiled]

        production = _timeseries(inner, :prod, profiled_units, T, sc = sc)
        sc_sol["Profiled: Production (MW)"] = production

        utilization = OrderedDict(
            pu.name => [
                round(
                    100.0 * value(inner[:prod][sc.name, pu.name, t]) /
                    pu.max_power[t],
                    digits = 2,
                ) for t in 1:T
            ] for pu in profiled_units
        )
        sc_sol["Profiled: Utilization (%)"] = utilization

        prod_cost = OrderedDict(
            pu.name => [
                value(inner[:prod][sc.name, pu.name, t]) * pu.cost[t]
                for t in 1:T
            ] for pu in profiled_units
        )
        sc_sol["Profiled: Production cost (\$)"] = prod_cost

        invest_status = OrderedDict(
            pu.name => value(inner[:invest][pu.name]) for
            pu in profiled_units if pu.invest > 0.0
        )
        sc_sol["Profiled: Investment status"] = invest_status

        qg = _timeseries(inner, :qg_profiled, profiled_units, T, sc = sc)
        sc_sol["Profiled: Reactive power (MVAr)"] = qg

        summary = sc_sol["Summary"]
        summary["Profiled: Total production cost (\$)"] = _total(prod_cost)
        total_available = sum(
            (sum(pu.max_power[t] for t in 1:T) for pu in profiled_units),
            init = 0.0,
        )
        total_produced = _total(production)
        summary["Profiled: Total curtailment (MW)"] =
            total_available - total_produced
        if total_available > 0
            summary["Profiled: Utilization (%)"] =
                100.0 * total_produced / total_available
        end

        # Investment
        invest_units = [pu for pu in profiled_units if pu.invest > 0.0]
        if !isempty(invest_units)
            summary["Profiled: Total investment cost (\$)"] = sum(
                invest_status[pu.name] * pu.invest for pu in invest_units
            )
            summary["Profiled: Units invested"] = count(
                pu -> invest_status[pu.name] > 0.5,
                invest_units,
            )
        end
    end

    return
end

function validate(
    instance::UnitCommitmentInstance,
    solution::AbstractDict,
    ::ProfiledUnitsExt;
    tol = 0.01,
)::Int
    err_count = 0

    for sc in instance.scenarios, pu in sc[:profiled]
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
    count = length(instance.scenarios[1][:profiled])
    print(io, "$count profiled units, ")
    return
end

function slice!(
    sc::UnitCommitmentScenario,
    range::UnitRange{Int},
    ::ProfiledUnitsExt,
)::Nothing
    for pu in sc[:profiled]
        pu.max_power = pu.max_power[range]
        pu.min_power = pu.min_power[range]
        pu.cost = pu.cost[range]
    end
    return
end
