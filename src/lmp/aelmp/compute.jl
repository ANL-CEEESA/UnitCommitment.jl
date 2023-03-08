# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using JuMP
"""
    function compute_lmp(
        model::JuMP.Model,
        method::AELMP.Method;
        optimizer = nothing,
    )

Calculates the approximate extended locational marginal prices of the given unit commitment instance.
The AELPM does the following three things:
1. It removes the minimum generation requirement for each generator
2. It averages the start-up cost over the offer blocks for each generator
3. It relaxes all the binary constraints and integrality
Returns a dictionary of AELMPs. Each key is usually a tuple of "Bus name" and time index.

NOTE: this approximation method is not fully developed. The implementation is based on MISO Phase I only.
1. It only supports Fast Start resources. More specifically, the minimum up/down time has to be zero.
2. The method does NOT support time series of start-up costs.
3. The method can only calculate for the first time slot if allow_offline_participation=false.

Arguments
---------

- `model`:
    the UnitCommitment model, must be solved before calling this function if offline participation is not allowed.

- `method`:
    the AELMP method, must be specified.

- `optimizer`:
    the optimizer for solving the LP problem.

Examples
--------

```julia

using UnitCommitment
using Cbc
using HiGHS

import UnitCommitment:
    AELMP

# Read benchmark instance
instance = UnitCommitment.read("instance.json")

# Construct model (using state-of-the-art defaults)
model = UnitCommitment.build_model(
    instance = instance,
    optimizer = Cbc.Optimizer,
    variable_names = true,
)

# Get the AELMP with the default policy: 
#   1. Offline generators are allowed to participate in pricing
#   2. Start-up costs are considered.
# DO NOT use Cbc as the optimizer here. Cbc does not support dual values.
my_aelmp_default = UnitCommitment.compute_lmp(
    model, # pre-solving is optional if allowing offline participation
    AELMP.Method(),
    optimizer = HiGHS.Optimizer
)

# Get the AELMPs with an alternative policy
#   1. Offline generators are NOT allowed to participate in pricing
#   2. Start-up costs are considered.
# UC model must be solved first if offline generators are NOT allowed
UnitCommitment.optimize!(model)

# then call the AELMP method
my_aelmp_alt = UnitCommitment.compute_lmp(
    model, # pre-solving is required here
    AELMP.Method(
        allow_offline_participation=false,
        consider_startup_costs=true
    ),
    optimizer = HiGHS.Optimizer
)

# Accessing the 'my_aelmp_alt' dictionary
# Example: "b1" is the bus name, 1 is the first time slot
@show my_aelmp_alt["b1", 1]

```

"""

function _preset_aelmp_parameters!(
    method::AELMP.Method,
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
    method::AELMP.Method
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

function compute_lmp(
    model::JuMP.Model,
    method::AELMP.Method;
    optimizer = nothing
)
    # Error if a linear optimizer is not specified
    if isnothing(optimizer)
        @error "Please supply a linear optimizer."
        return nothing
    end

    @info "Calculating the AELMP..."
    @info "Building the approximation model..."
    # get the instance and make a deep copy 
    instance = deepcopy(model[:instance])
    # preset the method to match the model status (solved, unsolved, not supplied)
    _preset_aelmp_parameters!(method, model)
    # modify the instance (generator)
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
    # set_silent(approx_model)
    optimize!(approx_model)

    # access the dual values
    @info "Getting dual values (AELMPs)."
    for (key, val) in approx_model[:eq_net_injection]
        elmp[key] = dual(val)
    end
    return elmp
end