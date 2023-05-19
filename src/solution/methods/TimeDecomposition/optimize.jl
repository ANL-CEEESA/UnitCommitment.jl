# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

"""
    optimize!(
        instance::UnitCommitmentInstance, 
        method::TimeDecomposition;
        optimizer,
    )::OrderedDict

Solve the given unit commitment instance with time decomposition. 
The model solves each sub-problem of a given time length specified by method.time_window,
and proceeds to the next sub-problem by incrementing the time length of method.time_increment.

Examples
--------

```julia
using UnitCommitment, Cbc

import UnitCommitment: 
    TimeDecomposition,
    Formulation,
    XavQiuWanThi2019

# assume the instance is given as a 120h problem
instance = UnitCommitment.read("instance.json")

solution = UnitCommitment.optimize!(
    instance,
    TimeDecomposition(
        time_window = 36,  # solve 36h problems
        time_increment = 24,  # advance by 24h each time
        inner_method = XavQiuWanThi2019.Method(),
        formulation = Formulation(),
    ),
    optimizer=Cbc.Optimizer
)
"""

function optimize!(
    instance::UnitCommitmentInstance,
    method::TimeDecomposition;
    optimizer,
)::OrderedDict
    # get instance total length
    T = instance.time
    solution = OrderedDict()
    iter = 0
    if length(instance.scenarios) > 1
        for sc in instance.scenarios
            solution[sc.name] = OrderedDict()
        end
    end
    # for each iteration, time increment by method.time_increment
    for t_start in 1:method.time_increment:T
        # set the initial status
        if iter > 0
            _set_initial_status!(instance, solution, method.time_increment)
        end
        t_end = t_start + method.time_window - 1
        # if t_end exceed total T
        t_end = t_end > T ? T : t_end
        # slice the model 
        modified = UnitCommitment.slice(instance, t_start:t_end)
        # solve the model 
        model = UnitCommitment.build_model(
            instance = modified,
            optimizer = optimizer,
            formulation = method.formulation,
        )
        UnitCommitment.optimize!(model, method.inner_method)
        # get the result of each time period
        sub_solution = UnitCommitment.solution(model)
        if length(instance.scenarios) == 1
            _update_solution!(solution, sub_solution, method.time_increment)
        else
            for sc in instance.scenarios
                _update_solution!(
                    solution[sc.name],
                    sub_solution[sc.name],
                    method.time_increment,
                )
            end
        end
        iter += 1 # increment iteration counter
    end
    return solution
end

"""
    _set_initial_status!(
        instance::UnitCommitmentInstance,
        solution::OrderedDict,
        time_increment::Int,
    )

Set the thermal units' initial power levels and statuses based on the first bunch of time slots 
specified by time_increment in the solution dictionary.
"""
function _set_initial_status!(
    instance::UnitCommitmentInstance,
    solution::OrderedDict,
    time_increment::Int,
)
    for sc in instance.scenarios
        for thermal_unit in sc.thermal_units
            if length(instance.scenarios) == 1
                prod = solution["Thermal production (MW)"][thermal_unit.name]
                is_on = solution["Is on"][thermal_unit.name]
            else
                prod =
                    solution[sc.name]["Thermal production (MW)"][thermal_unit.name]
                is_on = solution[sc.name]["Is on"][thermal_unit.name]
            end
            thermal_unit.initial_power = prod[time_increment]
            thermal_unit.initial_status = _determine_initial_status(
                thermal_unit.initial_status,
                is_on,
                time_increment,
            )
        end
    end
end

"""
    _determine_initial_status(
        prev_initial_status::Union{Float64,Int},
        status_sequence::Vector{Float64},
        time_increment::Int,
    )::Union{Float64,Int}

Determines a thermal unit's initial status based on its previous initial status, and
the on/off statuses in first bunch of time slots. 
"""
function _determine_initial_status(
    prev_initial_status::Union{Float64,Int},
    status_sequence::Vector{Float64},
    time_increment::Int,
)::Union{Float64,Int}
    # initialize the two flags
    on_status = prev_initial_status
    off_status = prev_initial_status
    # read through the status sequence
    # at each time if the unit is on, reset off_status, increment on_status
    # if the on_status < 0, set it to 1.0
    # at each time if the unit is off, reset on_status, decrement off_status
    # if the off_status > 0, set it to -1.0
    for t in 1:time_increment
        if status_sequence[t] == 1.0
            on_status = on_status < 0.0 ? 1.0 : on_status + 1.0
            off_status = 0.0
        else
            on_status = 0.0
            off_status = off_status > 0.0 ? -1.0 : off_status - 1.0
        end
    end
    # only one of them has non-zero value
    return on_status + off_status
end

"""
    _update_solution!(
        solution::OrderedDict,
        sub_solution::OrderedDict,
        time_increment::Int,
    )

Updates the solution (of each scenario) by concatenating the first bunch of 
time slots of the newly generated sub-solution to the end of the final solution dictionary.
This function traverses through the dictionary keys, finds the vector and finally
does the concatenation. For now, the function is hardcoded to traverse at most 3 layers
of depth until it finds a vector object.
"""
function _update_solution!(
    solution::OrderedDict,
    sub_solution::OrderedDict,
    time_increment::Int,
)
    # the solution has at most 3 layers
    for (l1_k, l1_v) in sub_solution
        for (l2_k, l2_v) in l1_v
            if l2_v isa Array
                # slice the sub_solution
                values_of_interest = l2_v[1:time_increment]
                sub_solution[l1_k][l2_k] = values_of_interest
                # append to the solution
                if !isempty(solution)
                    append!(solution[l1_k][l2_k], values_of_interest)
                end
            elseif l2_v isa OrderedDict
                for (l3_k, l3_v) in l2_v
                    # slice the sub_solution
                    values_of_interest = l3_v[1:time_increment]
                    sub_solution[l1_k][l2_k][l3_k] = values_of_interest
                    # append to the solution
                    if !isempty(solution)
                        append!(solution[l1_k][l2_k][l3_k], values_of_interest)
                    end
                end
            end
        end
    end

    # if solution is never initialized, deep copy the sliced sub_solution
    if isempty(solution)
        merge!(solution, sub_solution)
    end
end
