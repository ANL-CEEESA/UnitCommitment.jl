# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using JuMP

"""
    function compute_lmp(
        model::JuMP.Model,
        method::AELMP;
        optimizer,
    )::OrderedDict{Tuple{String,Int},Float64}

Calculates the approximate extended locational marginal prices of the given unit commitment instance.

The AELPM does the following three things:

    1. It sets the minimum power output of each generator to zero
    2. It averages the start-up cost over the offer blocks for each generator
    3. It relaxes all integrality constraints

Returns a dictionary mapping `(bus_name, time)` to the marginal price.

WARNING: This approximation method is not fully developed. The implementation is based on MISO Phase I only.

1. It only supports Fast Start resources. More specifically, the minimum up/down time has to be zero.
2. The method does NOT support time-varying start-up costs.
3. An asset is considered offline if it is never on throughout all time periods. 

Arguments
---------

- `model`:
    the UnitCommitment model, must be solved before calling this function if offline participation is not allowed.

- `method`:
    the AELMP method.

- `optimizer`:
    the optimizer for solving the LP problem.

Examples
--------

```julia
using UnitCommitment
using HiGHS

import UnitCommitment: AELMP

# Read benchmark instance
instance = UnitCommitment.read_benchmark("matpower/case118/2017-02-01")

# Build the model
model = UnitCommitment.build_model(
    instance = instance,
    optimizer = HiGHS.Optimizer,
)

# Optimize the model
UnitCommitment.optimize!(model)

# Compute the AELMPs
aelmp = UnitCommitment.compute_lmp(
    model,
    AELMP(
        allow_offline_participation = false,
        consider_startup_costs = true
    ),
    optimizer = HiGHS.Optimizer
)

# Access the AELMPs
# Example: "b1" is the bus name, 1 is the first time slot
@show aelmp["b1", 1]
```
"""
function compute_lmp(
    model::JuMP.Model,
    method::AELMP;
    optimizer,
)::OrderedDict{Tuple{String,Int},Float64}
    @info "Building the approximation model..."
    instance = deepcopy(model[:instance])
    _aelmp_check_parameters(instance, model, method)
    _modify_instance!(instance, model, method)

    # prepare the result dictionary and solve the model 
    elmp = OrderedDict()
    @info "Solving the approximation model."
    approx_model = build_model(instance = instance, variable_names = true)

    # relax the binary constraint, and relax integrality
    for v in all_variables(approx_model)
        if is_binary(v)
            unset_binary(v)
        end
    end
    relax_integrality(approx_model)
    set_optimizer(approx_model, optimizer)

    # solve the model 
    set_silent(approx_model)
    optimize!(approx_model)

    # access the dual values
    @info "Getting dual values (AELMPs)."
    for (key, val) in approx_model[:eq_net_injection]
        elmp[key] = dual(val)
    end
    return elmp
end

function _aelmp_check_parameters(
    instance::UnitCommitmentInstance,
    model::JuMP.Model,
    method::AELMP,
)
    # CHECK: model must be solved if allow_offline_participation=false
    if !method.allow_offline_participation
        if isnothing(model) || !has_values(model)
            error(
                "A solved UC model is required if allow_offline_participation=false.",
            )
        end
    end
    all_units = instance.units
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

function _modify_instance!(
    instance::UnitCommitmentInstance,
    model::JuMP.Model,
    method::AELMP,
)
    # this function modifies the instance units (generators)
    if !method.allow_offline_participation
        # 1. remove (if NOT allowing) the offline generators
        units_to_remove = []
        for unit in instance.units
            # remove based on the solved UC model result
            # remove the unit if it is never on
            if all(t -> value(model[:is_on][unit.name, t]) == 0, instance.time)
                # unregister from the bus 
                filter!(x -> x.name != unit.name, unit.bus.units)
                # unregister from the reserve
                for r in unit.reserves
                    filter!(x -> x.name != unit.name, r.units)
                end
                # append the name to the remove list
                push!(units_to_remove, unit.name)
            end
        end
        # unregister the units from the remove list
        filter!(x -> !(x.name in units_to_remove), instance.units)
    end

    for unit in instance.units
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
    return instance.units_by_name = Dict(g.name => g for g in instance.units)
end
