# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

"""
    solve_market(
        da_path::Union{String, Vector{String}},
        rt_paths::Vector{String},
        settings::MarketSettings;
        optimizer,
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
    the MarketSettings which include the problem formulation, the solving method, and extensions.

- `optimizer`:
    the optimizer for solving the problem.


Examples
--------

```julia
using UnitCommitment, HiGHS

import UnitCommitment:
    MarketSettings,
    XavQiuWanThi2019,
    ConventionalLMP

solution = UnitCommitment.solve_market(
    "da_instance.json",
    ["rt_instance_1.json", "rt_instance_2.json", "rt_instance_3.json"],
    MarketSettings(
        inner_method = XavQiuWanThi2019.Method(),
        extensions = [ConventionalLMP()],  # optional
    ),
    optimizer = HiGHS.Optimizer,
)
```
"""

function solve_market(
    da_path::Union{String,Vector{String}},
    rt_paths::Vector{String};
    settings::MarketSettings = MarketSettings(),
    optimizer,
)::OrderedDict
    # solve da instance as usual
    @info "Solving the day-ahead market with file $da_path..."
    instance_da = UnitCommitment.read(da_path, extensions = settings.extensions)
    # build and optimize the DA market
    _, solution_da =
        _build_and_optimize(instance_da, settings, optimizer = optimizer)
    # prepare the final solution
    solution = OrderedDict()
    solution["DA"] = solution_da
    solution["RT"] = []

    # count the time, sc[:time] = n-slots, sc[:time_step] = slot-interval
    # sufficient to look at only one scenario
    sc = instance_da.scenarios[1]

    # extract the DA commitment status from solution
    is_on_da = if length(instance_da.scenarios) == 1
        solution_da["Thermal: Is on"]
    else
        first(values(solution_da))["Thermal: Is on"]
    end
    # max time (min) of the DA market
    max_time = sc[:time] * sc[:time_step]
    # current time increments through the RT market list
    current_time = 0
    # DA market time slots in (min)
    da_time_intervals = [sc[:time_step] * ts for ts in 1:sc[:time]]

    # get the uc status and set each uc fixed
    solution_rt = OrderedDict()
    prev_initial_status = OrderedDict()
    for rt_path in rt_paths
        @info "Solving the real-time market with file $rt_path..."
        instance_rt =
            UnitCommitment.read(rt_path, extensions = settings.extensions)
        # check instance time
        sc = instance_rt.scenarios[1]
        # check each time slot in the RT model
        for ts in 1:sc[:time]
            slot_t_end = current_time + ts * sc[:time_step]
            # ensure this RT's slot time ub never exceeds max time of DA
            slot_t_end <= max_time || error(
                "The time of the real-time market cannot exceed the time of the day-ahead market.",
            )
            # get the slot start time to determine commitment status
            slot_t_start = slot_t_end - sc[:time_step]
            # find the index of the first DA time slot that covers slot_t_start
            da_time_slot = findfirst(ti -> slot_t_start < ti, da_time_intervals)
            # update thermal unit commitment status
            for g in sc[:thermal]
                g.commitment_status[ts] = is_on_da[g.name][da_time_slot] ≈ 1.0
            end
        end
        # update current time by ONE slot only
        current_time += sc[:time_step]
        # set initial status for all generators in all scenarios
        if !isempty(solution_rt) && !isempty(prev_initial_status)
            for g in sc[:thermal]
                g.initial_power =
                    solution_rt["Thermal: Production (MW)"][g.name][1]
                g.initial_status = UnitCommitment._determine_initial_status(
                    prev_initial_status[g.name],
                    [solution_rt["Thermal: Is on"][g.name][1]],
                )
            end
        end
        # build and optimize the RT market
        _, solution_rt =
            _build_and_optimize(instance_rt, settings, optimizer = optimizer)
        prev_initial_status =
            OrderedDict(g.name => g.initial_status for g in sc[:thermal])
        push!(solution["RT"], solution_rt)
    end # end of for-loop that checks each RT market
    return solution
end

function _build_and_optimize(
    instance::UnitCommitmentInstance,
    settings::MarketSettings;
    optimizer,
)::Tuple{UnitCommitmentModel,OrderedDict}
    # build model
    model =
        UnitCommitment.build_model(instance = instance, optimizer = optimizer)
    # optimize model
    UnitCommitment.optimize!(model, settings.inner_method)
    solution = UnitCommitment.solution(model)
    return model, solution
end
