# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

"""
    optimize!(
        instance::UnitCommitmentInstance, 
        method::TimeDecomposition;
        optimizer,
        after_build = nothing,
        after_optimize = nothing,
    )::OrderedDict

Solve the given unit commitment instance with time decomposition. 
The model solves each sub-problem of a given time length specified by method.time_window,
and proceeds to the next sub-problem by incrementing the time length of `method.time_increment`.

Arguments
---------

- `instance`:
    the UnitCommitment instance.

- `method`:
    the `TimeDecomposition` method.

- `optimizer`:
    the optimizer for solving the problem.

- `after_build`:
    a user-defined function that allows modifying the model after building,
    must have 2 arguments `model` and `instance` in order.

- `after_optimize`:
    a user-defined function that allows handling additional steps after optimizing,
    must have 3 arguments `solution`, `model` and `instance` in order.


Examples
--------

```julia
using UnitCommitment, JuMP, Cbc, HiGHS

import UnitCommitment: 
    TimeDecomposition,
    ConventionalLMP,
    XavQiuWanThi2019,
    Formulation

# specifying the after_build and after_optimize functions
function after_build(model, instance)
    @constraint(
        model,
        model[:is_on]["g3", 1] + model[:is_on]["g4", 1] <= 1,
    )
end

lmps = []
function after_optimize(solution, model, instance)
    lmp = UnitCommitment.compute_lmp(
        model,
        ConventionalLMP(),
        optimizer = HiGHS.Optimizer,
    )
    return push!(lmps, lmp)
end

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
    optimizer = Cbc.Optimizer,
    after_build = after_build,
    after_optimize = after_optimize,
)
"""

function optimize!(
    instance::UnitCommitmentInstance,
    method::TimeDecomposition;
    optimizer,
    after_build = nothing,
    after_optimize = nothing,
)::OrderedDict
    # get instance total length
    T = instance.time
    solution = OrderedDict()
    if length(instance.scenarios) > 1
        for sc in instance.scenarios
            solution[sc.name] = OrderedDict()
        end
    end
    # for each iteration, time increment by method.time_increment
    for t_start in 1:method.time_increment:T
        t_end = t_start + method.time_window - 1
        # if t_end exceed total T
        t_end = t_end > T ? T : t_end
        # slice the model 
        @info "Solving the sub-problem of time $t_start to $t_end..."
        sub_instance = UnitCommitment.slice(instance, t_start:t_end)
        # build and optimize the model 
        sub_model = UnitCommitment.build_model(
            instance = sub_instance,
            optimizer = optimizer,
            formulation = method.formulation,
        )
        if after_build !== nothing
            @info "Calling after build..."
            after_build(sub_model, sub_instance)
        end
        UnitCommitment.optimize!(sub_model, method.inner_method)
        # get the result of each time period
        sub_solution = UnitCommitment.solution(sub_model)
        if after_optimize !== nothing
            @info "Calling after optimize..."
            after_optimize(sub_solution, sub_model, sub_instance)
        end
        # merge solution 
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
        # set the initial status for the next sub-problem
        _set_initial_status!(instance, solution, method.time_increment)
    end
    return solution
end

"""
    _set_initial_status!(
        instance::UnitCommitmentInstance,
        solution::OrderedDict,
        time_increment::Int,
    )

Set the thermal units' initial power levels and statuses based on the last bunch of time slots 
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
            thermal_unit.initial_power = prod[end]
            thermal_unit.initial_status = _determine_initial_status(
                thermal_unit.initial_status,
                is_on[end-time_increment+1:end],
            )
        end
    end
end

"""
    _determine_initial_status(
        prev_initial_status::Union{Float64,Int},
        status_sequence::Vector{Float64},
    )::Union{Float64,Int}

Determines a thermal unit's initial status based on its previous initial status, and
the on/off statuses in the last operation.
"""
function _determine_initial_status(
    prev_initial_status::Union{Float64,Int},
    status_sequence::Vector{Float64},
)::Union{Float64,Int}
    # initialize the two flags
    on_status = prev_initial_status
    off_status = prev_initial_status
    # read through the status sequence
    # at each time if the unit is on, reset off_status, increment on_status
    # if the on_status < 0, set it to 1.0
    # at each time if the unit is off, reset on_status, decrement off_status
    # if the off_status > 0, set it to -1.0
    for status in status_sequence
        if status == 1.0
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
