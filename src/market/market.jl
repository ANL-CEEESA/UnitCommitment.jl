# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

"""
    solve_market(
        da_path::Union{String, Vector{String}}, 
        rt_paths::Vector{String},
        settings::MarketSettings;
        optimizer,
        lp_optimizer = nothing,
        after_build_da = nothing,
        after_optimize_da = nothing,
        after_build_rt = nothing,
        after_optimize_rt = nothing,
    )::OrderedDict

Solve the day-ahead and the real-time markets by the means of commitment status mapping.
The method firstly acquires the commitment status outcomes through the resolution of the day-ahead market; 
and secondly resolves each real-time market based on the corresponding results obtained previously.

Arguments
---------

- `da_path`:
    the data file path of the day-ahead market, can be stochastic.

- `rt_paths`:
    the list of data file paths of the real-time markets, must be deterministic for each market.

- `settings`:
    the MarketSettings which include the problem formulation, the solving method, and LMP method.

- `optimizer`:
    the optimizer for solving the problem.

- `lp_optimizer`:
    the linear programming optimizer for solving the LMP problem, defaults to `nothing`.
    If not specified by the user, the program uses `optimizer` instead.

- `after_build_da`:
    a user-defined function that allows modifying the DA model after building,
    must have 2 arguments `model` and `instance` in order.

- `after_optimize_da`:
    a user-defined function that allows handling additional steps after optimizing the DA model,
    must have 3 arguments `solution`, `model` and `instance` in order.

- `after_build_rt`:
    a user-defined function that allows modifying each RT model after building,
    must have 2 arguments `model` and `instance` in order.

- `after_optimize_rt`:
    a user-defined function that allows handling additional steps after optimizing each RT model,
    must have 3 arguments `solution`, `model` and `instance` in order.


Examples
--------

```julia
using UnitCommitment, Cbc, HiGHS

import UnitCommitment: 
    MarketSettings,
    XavQiuWanThi2019,
    ConventionalLMP,
    Formulation

solution = UnitCommitment.solve_market(
    "da_instance.json",
    ["rt_instance_1.json", "rt_instance_2.json", "rt_instance_3.json"],
    MarketSettings(
        inner_method = XavQiuWanThi2019.Method(),
        lmp_method = ConventionalLMP(),
        formulation = Formulation(),
    ),
    optimizer = Cbc.Optimizer,
    lp_optimizer = HiGHS.Optimizer,
)
"""

function solve_market(
    da_path::Union{String,Vector{String}},
    rt_paths::Vector{String},
    settings::MarketSettings;
    optimizer,
    lp_optimizer = nothing,
    after_build_da = nothing,
    after_optimize_da = nothing,
    after_build_rt = nothing,
    after_optimize_rt = nothing,
)::OrderedDict
    # solve da instance as usual
    @info "Solving the day-ahead market with file $da_path..."
    instance_da = UnitCommitment.read(da_path)
    # LP optimizer is optional: if not specified, use optimizer
    lp_optimizer = lp_optimizer === nothing ? optimizer : lp_optimizer
    # build and optimize the DA market
    model_da, solution_da = _build_and_optimize(
        instance_da,
        settings,
        optimizer = optimizer,
        lp_optimizer = lp_optimizer,
        after_build = after_build_da,
        after_optimize = after_optimize_da,
    )
    # prepare the final solution 
    solution = OrderedDict()
    solution["Day-ahead market"] = solution_da
    solution["Real-time markets"] = OrderedDict()

    # count the time, sc.time = n-slots, sc.time_step = slot-interval
    # sufficient to look at only one scenario
    sc = instance_da.scenarios[1]
    # max time (min) of the DA market
    max_time = sc.time * sc.time_step
    # current time increments through the RT market list
    current_time = 0
    # DA market time slots in (min)
    da_time_intervals = [sc.time_step * ts for ts in 1:sc.time]

    # get the uc status and set each uc fixed
    solution_rt = OrderedDict()
    prev_initial_status = OrderedDict()
    for rt_path in rt_paths
        @info "Solving the real-time market with file $rt_path..."
        instance_rt = UnitCommitment.read(rt_path)
        # check instance time 
        sc = instance_rt.scenarios[1]
        # check each time slot in the RT model
        for ts in 1:sc.time
            slot_t_end = current_time + ts * sc.time_step
            # ensure this RT's slot time ub never exceeds max time of DA
            slot_t_end <= max_time || error(
                "The time of the real-time market cannot exceed the time of the day-ahead market.",
            )
            # get the slot start time to determine commitment status
            slot_t_start = slot_t_end - sc.time_step
            # find the index of the first DA time slot that covers slot_t_start
            da_time_slot = findfirst(ti -> slot_t_start < ti, da_time_intervals)
            # update thermal unit commitment status
            for g in sc.thermal_units
                g.commitment_status[ts] =
                    value(model_da[:is_on][g.name, da_time_slot]) == 1.0
            end
        end
        # update current time by ONE slot only
        current_time += sc.time_step
        # set initial status for all generators in all scenarios
        if !isempty(solution_rt) && !isempty(prev_initial_status)
            for g in sc.thermal_units
                g.initial_power =
                    solution_rt["Thermal production (MW)"][g.name][1]
                g.initial_status = UnitCommitment._determine_initial_status(
                    prev_initial_status[g.name],
                    [solution_rt["Is on"][g.name][1]],
                )
            end
        end
        # build and optimize the RT market
        _, solution_rt = _build_and_optimize(
            instance_rt,
            settings,
            optimizer = optimizer,
            lp_optimizer = lp_optimizer,
            after_build = after_build_rt,
            after_optimize = after_optimize_rt,
        )
        prev_initial_status =
            OrderedDict(g.name => g.initial_status for g in sc.thermal_units)
        # rt_name = first(split(last(split(rt_path, "/")), "."))
        solution["Real-time markets"][rt_path] = solution_rt
    end # end of for-loop that checks each RT market
    return solution
end

function _build_and_optimize(
    instance::UnitCommitmentInstance,
    settings::MarketSettings;
    optimizer,
    lp_optimizer,
    after_build = nothing,
    after_optimize = nothing,
)::Tuple{JuMP.Model,OrderedDict}
    # build model with after build
    model = UnitCommitment.build_model(
        instance = instance,
        optimizer = optimizer,
        formulation = settings.formulation,
    )
    if after_build !== nothing
        after_build(model, instance)
    end
    # optimize model
    UnitCommitment.optimize!(model, settings.inner_method)
    solution = UnitCommitment.solution(model)
    # compute lmp and add to solution 
    if settings.lmp_method !== nothing
        lmp = UnitCommitment.compute_lmp(
            model,
            settings.lmp_method,
            optimizer = lp_optimizer,
        )
        if length(instance.scenarios) == 1
            solution["Locational marginal price"] = lmp
        else
            for sc in instance.scenarios
                solution[sc.name]["Locational marginal price"] = OrderedDict(
                    key => val for (key, val) in lmp if key[1] == sc.name
                )
            end
        end
    end
    # run after optimize with solution
    if after_optimize !== nothing
        after_optimize(solution, model, instance)
    end
    return model, solution
end
