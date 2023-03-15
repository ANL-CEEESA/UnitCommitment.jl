# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using JuMP

"""
    function compute_lmp(
        model::JuMP.Model,
        method::AELMP;
        optimizer = nothing,
    )

Calculates the approximate extended locational marginal prices of the given unit commitment instance.

The AELPM does the following three things:

    1. It sets the minimum power output of each generator to zero
    2. It averages the start-up cost over the offer blocks for each generator
    3. It relaxes all integrality constraints

Returns a dictionary mapping `(bus_name, time)` to the marginal price.

WARNING: This approximation method is not fully developed. The implementation is based on MISO Phase I only.

1. It only supports Fast Start resources. More specifically, the minimum up/down time has to be zero.
2. The method does NOT support time series of start-up costs.
3. The method can only calculate for the first time slot if allow_offline_participation=false.

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
    @info "Calculating the AELMP..."
    @info "Building the approximation model..."
    instance = deepcopy(model[:instance])
    _preset_aelmp_parameters!(method, model)
    _modify_instance!(instance, model, method)

    # prepare the result dictionary and solve the model 
    elmp = OrderedDict()
    @info "Solving the approximation model."
    approx_model = build_model(instance=instance, variable_names=true)

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

function _preset_aelmp_parameters!(
    method::AELMP,
    model::JuMP.Model
)
    # this function corrects the allow_offline_participation parameter to match the model status
    # CHECK: model must be solved if allow_offline_participation=false
    if method.allow_offline_participation # do nothing
        @info "Offline generators are allowed to participate in pricing."
    else
        if isnothing(model)
            @warn "No UC model is detected. A solved UC model is required if allow_offline_participation == false."
            @warn "Setting parameter allow_offline_participation = true"
            method.allow_offline_participation = true # and do nothing else
        elseif !has_values(model)
            @warn "The UC model has no solution. A solved UC model is required if allow_offline_participation == false."
            @warn "Setting parameter allow_offline_participation = true"
            method.allow_offline_participation = true # and do nothing else
        else
            # the inputs are correct
            @info "Offline generators are NOT allowed to participate in pricing."
            @info "Offline generators will be removed for the approximation."
        end
    end

    # CHECK: start up cost consideration
    if method.consider_startup_costs
        @info "Startup costs are considered."
    else 
        @info "Startup costs are NOT considered."
    end
end

function _modify_instance!(
    instance::UnitCommitmentInstance,
    model::JuMP.Model,
    method::AELMP
)
    # this function modifies the instance units (generators)
    # 1. remove (if NOT allowing) the offline generators
    if !method.allow_offline_participation
        for unit in instance.units
            # remove based on the solved UC model result
            # here, only look at the first time slot (TIME-SERIES-NOT-SUPPORTED)
            if value(model[:is_on][unit.name, 1]) == 0
                # unregister from the bus 
                filter!(x -> x.name != unit.name, unit.bus.units)
                # unregister from the reserve
                for r in unit.reserves
                    filter!(x -> x.name != unit.name, r.units)
                end
            end
        end
        # unregister the units
        filter!(x -> value(model[:is_on][x.name, 1]) != 0, instance.units)
    end

    for unit in instance.units
        # 2. set min generation requirement to 0 by adding 0 to production curve and cost 
        # min_power & min_costs are vectors with dimension T
        if unit.min_power[1] != 0
            first_cost_segment = unit.cost_segments[1]
            pushfirst!(unit.cost_segments, CostSegment(
                ones(size(first_cost_segment.mw)) * unit.min_power[1],
                ones(size(first_cost_segment.cost)) * unit.min_power_cost[1] / unit.min_power[1]
            ))
            unit.min_power = zeros(size(first_cost_segment.mw))
            unit.min_power_cost = zeros(size(first_cost_segment.cost))
        end

        # 3. average the start-up costs (if considering)
        # for now, consider first element only (TIME-SERIES-NOT-SUPPORTED)
        # if consider_startup_costs = false, then use the current first_startup_cost
        first_startup_cost = unit.startup_categories[1].cost
        if method.consider_startup_costs
            additional_unit_cost = first_startup_cost / unit.max_power[1]
            for i in eachindex(unit.cost_segments)
                unit.cost_segments[i].cost .+= additional_unit_cost
            end
            first_startup_cost = 0.0 # zero out the start up cost
        end

        # 4. other adjustments...
        ### FIXME in the future
        # MISO Phase I: can ONLY solve fast-starts, force all startup time to be 0
        unit.startup_categories = StartupCategory[StartupCategory(0, first_startup_cost)]
        unit.initial_status = -100
        unit.initial_power = 0
        unit.min_uptime = 0
        unit.min_downtime = 0
        ### END FIXME
    end
    instance.units_by_name = Dict(g.name => g for g in instance.units)
end