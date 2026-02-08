# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

function _add_storage_units!(
    model::JuMP.Model,
    instance::UnitCommitmentInstance,
)::Nothing
    _add_storage_vars!(model, instance)
    _add_storage_obj!(model, instance)
    _add_storage_constrs!(model, instance)
    _add_storage_constr_invest!(model, instance)
    return
end

function _add_storage_vars!(
    model::JuMP.Model,
    instance::UnitCommitmentInstance,
)::Nothing
    T = instance.time
    storage_level = _init(model, :storage_level)
    charge_rate = _init(model, :charge_rate)
    discharge_rate = _init(model, :discharge_rate)
    is_charging = _init(model, :is_charging)
    is_discharging = _init(model, :is_discharging)
    invest_storage = _init(model, :invest_storage)

    for sc in instance.scenarios, su in sc.storage_units
        for t in 1:T
            storage_level[sc.name, su.name, t] = @variable(
                model,
                lower_bound = su.invest[1] > 0.0 ? 0.0 : su.min_level[t],
                upper_bound = su.max_level[t],
            )
            charge_rate[sc.name, su.name, t] = @variable(model)
            discharge_rate[sc.name, su.name, t] = @variable(model)
            is_charging[sc.name, su.name, t] = @variable(model, binary = true)
            is_discharging[sc.name, su.name, t] =
                @variable(model, binary = true)

            # Net injection
            add_to_expression!(
                model[:net_injection][sc.name, su.bus.name, t],
                discharge_rate[sc.name, su.name, t],
                1.0,
            )
            add_to_expression!(
                model[:net_injection][sc.name, su.bus.name, t],
                charge_rate[sc.name, su.name, t],
                -1.0,
            )
        end
    end

    # Investment
    for su in instance.scenarios[1].storage_units
        su.invest[1] > 0.0 || continue
        invest_storage[su.name, 0] = 0.0
        for t in 1:T
            invest_storage[su.name, t] = @variable(model, binary = true)
        end
    end
    return
end

function _add_storage_obj!(
    model::JuMP.Model,
    instance::UnitCommitmentInstance,
)::Nothing
    T = instance.time
    charge_rate = model[:charge_rate]
    discharge_rate = model[:discharge_rate]
    invest_storage = model[:invest_storage]

    # Charge and discharge costs
    for t in 1:T, sc in instance.scenarios, su in sc.storage_units
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
    end

    # Investment costs
    for su in instance.scenarios[1].storage_units
        su.invest[1] > 0.0 || continue
        for t in 1:T
            add_to_expression!(
                model[:obj],
                invest_storage[su.name, t] - invest_storage[su.name, t-1],
                su.invest[t] * instance.scenarios[1].investment_cost_weight,
            )
        end
    end

    return
end

function _add_storage_constrs!(
    model::JuMP.Model,
    instance::UnitCommitmentInstance,
)::Nothing
    T = instance.time
    time_step = instance.scenarios[1].time_step / 60

    storage_level = model[:storage_level]
    charge_rate = model[:charge_rate]
    discharge_rate = model[:discharge_rate]
    is_charging = model[:is_charging]
    is_discharging = model[:is_discharging]

    eq_simultaneous_charge_and_discharge =
        _init(model, :eq_simultaneous_charge_and_discharge)
    eq_min_charge_rate = _init(model, :eq_min_charge_rate)
    eq_max_charge_rate = _init(model, :eq_max_charge_rate)
    eq_min_discharge_rate = _init(model, :eq_min_discharge_rate)
    eq_max_discharge_rate = _init(model, :eq_max_discharge_rate)
    eq_storage_transition = _init(model, :eq_storage_transition)
    eq_ending_level = _init(model, :eq_ending_level)

    for sc in instance.scenarios, su in sc.storage_units
        for t in 1:T
            # Simultaneous charging and discharging
            if !su.simultaneous_charge_and_discharge[t]
                eq_simultaneous_charge_and_discharge[sc.name, su.name, t] =
                    @constraint(
                        model,
                        is_charging[sc.name, su.name, t] +
                        is_discharging[sc.name, su.name, t] <= 1.0
                    )
            end

            # Charge rate limits
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

            # Discharge rate limits
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

            # Storage energy transition
            prev_level =
                t == 1 ? su.initial_level : storage_level[sc.name, su.name, t-1]
            eq_storage_transition[sc.name, su.name, t] = @constraint(
                model,
                storage_level[sc.name, su.name, t] ==
                (1 - su.loss_factor[t]) * prev_level +
                charge_rate[sc.name, su.name, t] *
                time_step *
                su.charge_efficiency[t] -
                discharge_rate[sc.name, su.name, t] * time_step /
                su.discharge_efficiency[t]
            )

            # Ending level
            if t == T
                eq_ending_level[sc.name, su.name] = @constraint(
                    model,
                    su.min_ending_level <=
                    storage_level[sc.name, su.name, t] <=
                    su.max_ending_level
                )
            end
        end
    end
    return
end

function _add_storage_constr_invest!(
    model::JuMP.Model,
    instance::UnitCommitmentInstance,
)::Nothing
    T = instance.time
    storage_level = model[:storage_level]
    invest_storage = model[:invest_storage]

    eq_invest_storage_nondec = _init(model, :eq_invest_storage_nondec)
    eq_invest_storage_level_ub = _init(model, :eq_invest_storage_level_ub)
    eq_invest_storage_level_lb = _init(model, :eq_invest_storage_level_lb)

    # Investment is irreversible
    for su in instance.scenarios[1].storage_units
        su.invest[1] > 0.0 || continue
        for t in 2:T
            eq_invest_storage_nondec[su.name, t] = @constraint(
                model,
                invest_storage[su.name, t-1] <= invest_storage[su.name, t],
            )
        end
    end

    # Storage level bounds depend on investment status
    for sc in instance.scenarios, su in sc.storage_units
        su.invest[1] > 0.0 || continue
        for t in 1:T
            eq_invest_storage_level_ub[sc.name, su.name, t] = @constraint(
                model,
                storage_level[sc.name, su.name, t] <=
                su.max_level[t] * invest_storage[su.name, t],
            )
            eq_invest_storage_level_lb[sc.name, su.name, t] = @constraint(
                model,
                storage_level[sc.name, su.name, t] >=
                su.min_level[t] * invest_storage[su.name, t],
            )
        end
    end

    return
end
