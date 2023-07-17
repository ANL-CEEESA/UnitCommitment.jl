# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

function _add_storage_unit!(
    model::JuMP.Model,
    su::StorageUnit,
    sc::UnitCommitmentScenario,
)::Nothing
    # Initialize variables
    storage_level = _init(model, :storage_level)
    charge_rate = _init(model, :charge_rate)
    discharge_rate = _init(model, :discharge_rate)
    is_charging = _init(model, :is_charging)
    is_discharging = _init(model, :is_discharging)
    eq_min_charge_rate = _init(model, :eq_min_charge_rate)
    eq_max_charge_rate = _init(model, :eq_max_charge_rate)
    eq_min_discharge_rate = _init(model, :eq_min_discharge_rate)
    eq_max_discharge_rate = _init(model, :eq_max_discharge_rate)
    # Initialize constraints
    net_injection = _init(model, :expr_net_injection)
    eq_storage_transition = _init(model, :eq_storage_transition)
    eq_ending_level = _init(model, :eq_ending_level)
    # time in hours
    time_step = sc.time_step / 60

    for t in 1:model[:instance].time
        # Decision variable
        storage_level[sc.name, su.name, t] = @variable(
            model,
            lower_bound = su.min_level[t],
            upper_bound = su.max_level[t]
        )
        charge_rate[sc.name, su.name, t] = @variable(model)
        discharge_rate[sc.name, su.name, t] = @variable(model)
        is_charging[sc.name, su.name, t] = @variable(model, binary = true)
        is_discharging[sc.name, su.name, t] = @variable(model, binary = true)

        # Objective function terms ##### CHECK & FIXME
        add_to_expression!(
            model[:obj],
            charge_rate[sc.name, su.name, t],
            su.charge_cost[t] * sc.probability,
        )

        add_to_expression!(
            model[:obj],
            discharge_rate[sc.name, su.name, t],
            su.discharge_cost[t] * sc.probability,
        )

        # Net injection
        add_to_expression!(
            net_injection[sc.name, su.bus.name, t],
            discharge_rate[sc.name, su.name, t],
            1.0,
        )
        add_to_expression!(
            net_injection[sc.name, su.bus.name, t],
            charge_rate[sc.name, su.name, t],
            -1.0,
        )

        # Simultaneous charging and discharging
        if !su.simultaneous_charge_and_discharge[t]
            # Initialize the model dictionary
            eq_simultaneous_charge_and_discharge =
                _init(model, :eq_simultaneous_charge_and_discharge)
            # Constraints
            eq_simultaneous_charge_and_discharge[sc.name, su.name, t] =
                @constraint(
                    model,
                    is_charging[sc.name, su.name, t] +
                    is_discharging[sc.name, su.name, t] <= 1.0
                )
        end

        # Charge and discharge constraints
        eq_min_charge_rate[sc.name, su.name, t] = @constraint(
            model,
            charge_rate[sc.name, su.name, t] >=
            is_charging[sc.name, su.name, t] * su.min_charge_rate[t]
        )
        eq_max_charge_rate[sc.name, su.name, t] = @constraint(
            model,
            charge_rate[sc.name, su.name, t] <=
            is_charging[sc.name, su.name, t] * su.max_charge_rate[t]
        )
        eq_min_discharge_rate[sc.name, su.name, t] = @constraint(
            model,
            discharge_rate[sc.name, su.name, t] >=
            is_discharging[sc.name, su.name, t] * su.min_discharge_rate[t]
        )
        eq_max_discharge_rate[sc.name, su.name, t] = @constraint(
            model,
            discharge_rate[sc.name, su.name, t] <=
            is_discharging[sc.name, su.name, t] * su.max_discharge_rate[t]
        )

        # Storage energy transition constraint 
        prev_storage_level =
            t == 1 ? su.initial_level : storage_level[sc.name, su.name, t-1]
        eq_storage_transition[sc.name, su.name, t] = @constraint(
            model,
            storage_level[sc.name, su.name, t] ==
            (1 - su.loss_factor[t]) * prev_storage_level +
            charge_rate[sc.name, su.name, t] *
            time_step *
            su.charge_efficiency[t] -
            discharge_rate[sc.name, su.name, t] * time_step /
            su.discharge_efficiency[t]
        )

        # Storage ending level constraint 
        if t == sc.time
            eq_ending_level[sc.name, su.name] = @constraint(
                model,
                su.min_ending_level <=
                storage_level[sc.name, su.name, t] <=
                su.max_ending_level
            )
        end
    end
    return
end
