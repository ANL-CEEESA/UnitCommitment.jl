# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using JuMP
using UnitCommitment

function _after_optimize!(
    model::JuMP.Model,
    method::AELMP,
)::Nothing
    @info "Building the approximation model..."
    instance = deepcopy(model[:instance])
    _aelmp_check_parameters(instance, model, method)
    _modify_scenario!(instance.scenarios[1], model, method)

    @info "Solving the approximation model."
    approx_model = build_model(instance = instance, variable_names = true)

    # Relax the binary constraint, and relax integrality
    for v in all_variables(approx_model)
        if is_binary(v)
            unset_binary(v)
        end
    end
    relax_integrality(approx_model)
    set_optimizer(approx_model, method.optimizer)

    # Solve the model
    set_silent(approx_model)
    JuMP.optimize!(approx_model)

    # Store dual values as LMPs
    @info "Getting dual values (AELMPs)."
    model.ext[:lmp_values] = OrderedDict()
    for (key, val) in approx_model[:eq_net_injection]
        model.ext[:lmp_values][key] = dual(val)
    end
end

function _solution!(
    sol::AbstractDict,
    model::JuMP.Model,
    ::AELMP,
)::Nothing
    instance = model[:instance]
    T = instance.time
    for sc in instance.scenarios
        lmp = sol[sc.name]["Locational marginal price (\$/MWh)"] = Dict()
        for b in sc.buses, t in 1:T
            lmp[b.name, t] = model.ext[:lmp_values][sc.name, b.name, t]
        end
    end
    return
end

function _aelmp_check_parameters(
    instance::UnitCommitmentInstance,
    model::JuMP.Model,
    method::AELMP,
)
    # CHECK: model cannot have multiple scenarios
    if length(instance.scenarios) > 1
        error("The method does NOT support multiple scenarios.")
    end
    sc = instance.scenarios[1]
    # CHECK: model must be solved if allow_offline_participation=false
    if !method.allow_offline_participation
        if isnothing(model) || !has_values(model)
            error(
                "A solved UC model is required if allow_offline_participation=false.",
            )
        end
    end
    all_units = sc.thermal_units
    # CHECK: model cannot handle non-fast-starts (MISO Phase I: can ONLY solve fast-starts)
    if any(u -> u.min_uptime > 1 || u.min_downtime > 1, all_units)
        error(
            "The minimum up/down time of all generators must be 1. AELMP only supports fast-starts.",
        )
    end
    if any(u -> u.initial_power > 0, all_units)
        error("The initial power of all generators must be 0.")
    end
    if any(u -> u.initial_status >= 0, all_units)
        error("The initial status of all generators must be negative.")
    end
    # CHECK: model does not support startup costs (in time series)
    if any(u -> length(u.startup_categories) > 1, all_units)
        error("The method does NOT support time-varying start-up costs.")
    end
end

function _modify_scenario!(
    sc::UnitCommitmentScenario,
    model::JuMP.Model,
    method::AELMP,
)
    # this function modifies the sc units (generators)
    if !method.allow_offline_participation
        # 1. remove (if NOT allowing) the offline generators
        units_to_remove = []
        for unit in sc.thermal_units
            # remove based on the solved UC model result
            # remove the unit if it is never on
            if all(t -> value(model[:is_on][unit.name, t]) == 0, sc.time)
                # unregister from the bus
                filter!(x -> x.name != unit.name, unit.bus.thermal_units)
                # unregister from the reserve
                for r in unit.reserves
                    filter!(x -> x.name != unit.name, r.thermal_units)
                end
                # append the name to the remove list
                push!(units_to_remove, unit.name)
            end
        end
        # unregister the units from the remove list
        filter!(x -> !(x.name in units_to_remove), sc.thermal_units)
    end

    for unit in sc.thermal_units
        # 2. set min generation requirement to 0 by adding 0 to production curve and cost
        # min_power & min_costs are vectors with dimension T
        if unit.min_power[1] != 0
            first_cost_segment = unit.cost_segments[1]
            pushfirst!(
                unit.cost_segments,
                CostSegment(
                    ones(size(first_cost_segment.mw)) * unit.min_power[1],
                    ones(size(first_cost_segment.cost)) *
                    unit.min_power_cost[1] / unit.min_power[1],
                ),
            )
            unit.min_power = zeros(size(first_cost_segment.mw))
            unit.min_power_cost = zeros(size(first_cost_segment.cost))
        end

        # 3. average the start-up costs (if considering)
        # if consider_startup_costs = false, then use the current first_startup_cost
        first_startup_cost = unit.startup_categories[1].cost
        if method.consider_startup_costs
            additional_unit_cost = first_startup_cost / unit.max_power[1]
            for i in eachindex(unit.cost_segments)
                unit.cost_segments[i].cost .+= additional_unit_cost
            end
            first_startup_cost = 0.0 # zero out the start up cost
        end
        unit.startup_categories =
            StartupCategory[StartupCategory(0, first_startup_cost)]
    end
    return sc.thermal_units_by_name =
        Dict(g.name => g for g in sc.thermal_units)
end
