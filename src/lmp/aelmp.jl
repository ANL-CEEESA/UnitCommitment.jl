# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using JuMP
using UnitCommitment

function _after_optimize!(instance::UnitCommitmentInstance, model::UnitCommitmentModel, method::AELMP)::Nothing
    # Build the approximation model
    approx_instance = deepcopy(instance)
    _aelmp_check_parameters(approx_instance, model, method)
    _modify_scenario!(approx_instance.scenarios[1], model, method)
    approx_model = build_model(approx_instance, variable_names = true)
    for v in all_variables(approx_model.inner)
        if is_binary(v)
            unset_binary(v)
        end
    end
    relax_integrality(approx_model.inner)
    set_optimizer(approx_model.inner, method.optimizer)

    # Solve the approximation model
    set_silent(approx_model.inner)
    JuMP.optimize!(approx_model.inner)

    # Store LMPs
    model.data[:lmp] = OrderedDict()
    for (key, val) in approx_model.inner[:eq_net_injection]
        model.data[:lmp][key] = -dual(val)
    end
    _update_solution(instance, model, ConventionalLMP())
end

function _aelmp_check_parameters(
    instance::UnitCommitmentInstance,
    model::UnitCommitmentModel,
    method::AELMP,
)
    # CHECK: model cannot have multiple scenarios
    if length(instance.scenarios) > 1
        error("The method does NOT support multiple scenarios.")
    end
    sc = instance.scenarios[1]
    # CHECK: model must be solved if allow_offline_participation=false
    if !method.allow_offline_participation
        if !has_values(model.inner)
            error(
                "A solved UC model is required if allow_offline_participation=false.",
            )
        end
    end
    all_units = sc[:thermal]
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
    model::UnitCommitmentModel,
    method::AELMP,
)
    # this function modifies the sc units (generators)
    if !method.allow_offline_participation
        # 1. remove (if NOT allowing) the offline generators
        units_to_remove = []
        for unit in sc[:thermal]
            # remove based on the solved UC model result
            # remove the unit if it is never on
            if all(t -> value(model.inner[:is_on][unit.name, t]) == 0, sc[:time])
                # unregister from the reserve
                for r in unit.reserves
                    filter!(x -> x.name != unit.name, r.thermal_units)
                end
                # append the name to the remove list
                push!(units_to_remove, unit.name)
            end
        end
        # unregister the units from the remove list
        filter!(x -> !(x.name in units_to_remove), sc[:thermal])
    end

    for unit in sc[:thermal]
        # 2. set min generation requirement to 0 by adding 0 to production curve and cost
        # min_power & min_costs are vectors with dimension T
        if unit.min_power[1] != 0
            first_cost_segment = unit.cost_segments[1]
            pushfirst!(
                unit.cost_segments,
                CostSegment(
                    mw = ones(size(first_cost_segment.mw)) * unit.min_power[1],
                    cost = ones(size(first_cost_segment.cost)) *
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
        unit.startup_categories = StartupCategory[StartupCategory(
            delay = 0,
            cost = first_startup_cost,
        )]
    end
    return sc[:thermal_by_name] = Dict(g.name => g for g in sc[:thermal])
end
