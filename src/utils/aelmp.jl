# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using JuMP
using Clp

"""
    function get_aelmp(
        path::String;
        optimizer = nothing,
        solved_uc_model::Union{JuMP.Model, Nothing} = nothing,
        allow_offline_participation::Bool = true,
        consider_startup_costs::Bool = true
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

- `path`:
    the file path of the input data.

-  `optimizer`:
    the optimizer for solving the problem. If not specified, the method will use Clp.

- `solved_uc_model`:
    the original unit commitment model that has been solved. This is used ONLY with allow_offline_participation
    being set to false. 

- `allow_offline_participation`:
    defaults to true. If true, offline assets are allowed to participate in pricing; otherwise those 
    assets are NOT allowed to participate.

- `consider_startup_costs`:
    defaults to true. If true, the start-up costs are averaged over each unit production; otherwise the 
    production costs stay the same.

Examples
--------

```julia

using UnitCommitment
using Clp 

# Get the AELMPs with the file path (default policy)
aelmp = UnitCommitment.get_aelmp(
    "example.json", 
    optimizer = Clp.Optimizer,
)

# Get the AELMPs with an alternative policy
# Do not allow offline generators for price participation
# solve the UC model first 
instance = UnitCommitment.read("example.json")
model = UnitCommitment.build_model(
    instance=instance,
    optimizer=Clp.Optimizer,
    variable_names = true,
)
UnitCommitment.optimize!(model)
# then call the AELMP method
aelmp = UnitCommitment.get_aelmp(
    "example.json", 
    solved_uc_model = model,
    allow_offline_participation = false,
)

# Accessing the 'aelmp' dictionary
# Example: "b1" is the bus name, 1 is the first time slot
@show aelmp["b1", 1]

```

"""

function get_aelmp(
    path::String;
    optimizer = nothing,
    solved_uc_model::Union{JuMP.Model, Nothing} = nothing,
    allow_offline_participation::Bool = true,
    consider_startup_costs::Bool = true
)
    @info "Calculating the AELMP..."
    @info "Building the approximation model..."
    # get the json object from file path.
    json = _read_json(path)

    # if optimizer is not specified, use Clp
    if isnothing(optimizer)
        optimizer = Clp.Optimizer
    end

    # CHECK: model must be solved if allow_offline_participation=false
    if allow_offline_participation # do nothing
        @info "Offline generators are allowed to participate in pricing."
    else
        if isnothing(solved_uc_model)
            @warn "No UC model is detected. A solved UC model is required if allow_offline_participation == false."
            @warn "Setting parameter allow_offline_participation = true"
            allow_offline_participation = true # and do nothing else
        elseif !has_values(solved_uc_model)
            @warn "The UC model has no solution. A solved UC model is required if allow_offline_participation == false."
            @warn "Setting parameter allow_offline_participation = true"
            allow_offline_participation = true # and do nothing else
        else
            # the inputs are correct
            @info "Offline generators are NOT allowed to participate in pricing."
            @info "Offline generators will be removed for the approximation."
        end
    end

    # CHECK: start up cost consideration
    if consider_startup_costs
        @info "Startup costs are considered."
    else 
        @info "Startup costs are NOT considered."
    end

    # modify the data for each generator
    for (unit_name, dict) in json["Generators"]
        # 1. remove (if NOT allowing) the offline generators
        if !allow_offline_participation
            # remove based on the solved UC model result
            # here, only look at the first time slot (TIME-SERIES-NOT-SUPPORTED)
            is_on = value(solved_uc_model[:is_on][unit_name, 1])
            if is_on == 0
                delete!(json["Generators"], unit_name)
                continue
            end
        end

        # 2. set min generation requirement to 0 by adding 0 to production curve and cost 
        cost_curve_mw = dict["Production cost curve (MW)"]
        cost_curve_dollar = dict["Production cost curve (\$)"]
        if cost_curve_mw[1] != 0
            pushfirst!(cost_curve_mw, 0)
            pushfirst!(cost_curve_dollar, 0)
            dict["Production cost curve (MW)"] = cost_curve_mw
            dict["Production cost curve (\$)"] = cost_curve_dollar
        end

        # 3. average the start-up costs (if considering)
        # for now, consider first element only (TIME-SERIES-NOT-SUPPORTED)
        first_startup_cost = dict["Startup costs (\$)"][1]
        if consider_startup_costs
            additional_unit_cost = first_startup_cost / cost_curve_mw[end]
            for i in eachindex(cost_curve_dollar)
                cost_curve_dollar[i] += additional_unit_cost * cost_curve_mw[i]
            end
            dict["Production cost curve (\$)"] = cost_curve_dollar
            dict["Startup costs (\$)"] = [0.0]
        else 
            # or do nothing (just keep the first cost)
            dict["Startup costs (\$)"] = [first_startup_cost]
        end

        # 4. other adjustments...
        ### FIXME in the future
        # MISO Phase I: can ONLY solve fast-starts
        # here, force all startup time to be 0
        dict["Startup delays (h)"] = [0]
        dict["Initial status (h)"] = -100
        dict["Initial power (MW)"] = 0
        dict["Minimum uptime (h)"] = 0
        dict["Minimum downtime (h)"] = 0
        ### END FIXME

        # update
        json["Generators"][unit_name] = dict
    end

    # prepare the result dictionary and solve the model 
    elmp = Dict()

    # init the model 
    @info "Solving the approximation model."
    instance = _from_json(json) # obtain the instance object
    model = build_model(
        instance=instance,
        variable_names=true,
    )

    # relax the binary constraint, and relax integrality
    for v in all_variables(model)
        if is_binary(v)
            unset_binary(v)
        end
    end
    relax_integrality(model)
    set_optimizer(model, optimizer)

    # solve the model 
    set_silent(model)
    optimize!(model)

    # access the dual values
    @info "Getting dual values (AELMPs)."
    for (key, val) in model[:eq_net_injection]
        elmp[key] = dual(val)
    end
    return elmp
end