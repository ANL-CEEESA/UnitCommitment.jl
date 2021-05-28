# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using JuMP, MathOptInterface, DataStructures
import JuMP: value, fix, set_name

# Extend some JuMP functions so that decision variables can be safely replaced by
# (constant) floating point numbers.
function value(x::Float64)
    return x
end

function fix(x::Float64, v::Float64; force)
    return abs(x - v) < 1e-6 || error("Value mismatch: $x != $v")
end

function set_name(x::Float64, n::String)
    # nop
end

function build_model(;
    filename::Union{String,Nothing} = nothing,
    instance::Union{UnitCommitmentInstance,Nothing} = nothing,
    isf::Union{Matrix{Float64},Nothing} = nothing,
    lodf::Union{Matrix{Float64},Nothing} = nothing,
    isf_cutoff::Float64 = 0.005,
    lodf_cutoff::Float64 = 0.001,
    optimizer = nothing,
    variable_names::Bool = false,
)::JuMP.Model
    if (filename === nothing) && (instance === nothing)
        error("Either filename or instance must be specified")
    end

    if filename !== nothing
        @info "Reading: $(filename)"
        time_read = @elapsed begin
            instance = UnitCommitment.read(filename)
        end
        @info @sprintf("Read problem in %.2f seconds", time_read)
    end

    if length(instance.buses) == 1
        isf = zeros(0, 0)
        lodf = zeros(0, 0)
    else
        if isf === nothing
            @info "Computing injection shift factors..."
            time_isf = @elapsed begin
                isf = UnitCommitment._injection_shift_factors(
                    lines = instance.lines,
                    buses = instance.buses,
                )
            end
            @info @sprintf("Computed ISF in %.2f seconds", time_isf)

            @info "Computing line outage factors..."
            time_lodf = @elapsed begin
                lodf = UnitCommitment._line_outage_factors(
                    lines = instance.lines,
                    buses = instance.buses,
                    isf = isf,
                )
            end
            @info @sprintf("Computed LODF in %.2f seconds", time_lodf)

            @info @sprintf(
                "Applying PTDF and LODF cutoffs (%.5f, %.5f)",
                isf_cutoff,
                lodf_cutoff
            )
            isf[abs.(isf).<isf_cutoff] .= 0
            lodf[abs.(lodf).<lodf_cutoff] .= 0
        end
    end

    @info "Building model..."
    time_model = @elapsed begin
        model = Model()
        if optimizer !== nothing
            set_optimizer(model, optimizer)
        end
        model[:obj] = AffExpr()
        model[:instance] = instance
        model[:isf] = isf
        model[:lodf] = lodf
        for field in [
            :prod_above,
            :segprod,
            :reserve,
            :is_on,
            :switch_on,
            :switch_off,
            :net_injection,
            :curtail,
            :overflow,
            :loads,
            :startup,
            :eq_startup_choose,
            :eq_startup_restrict,
            :eq_segprod_limit,
            :eq_prod_above_def,
            :eq_prod_limit,
            :eq_binary_link,
            :eq_switch_on_off,
            :eq_ramp_up,
            :eq_ramp_down,
            :eq_startup_limit,
            :eq_shutdown_limit,
            :eq_min_uptime,
            :eq_min_downtime,
            :eq_power_balance,
            :eq_net_injection_def,
            :eq_min_reserve,
            :expr_inj,
            :expr_reserve,
            :expr_net_injection,
        ]
            model[field] = OrderedDict()
        end
        for lm in instance.lines
            _add_transmission_line!(model, lm)
        end
        for b in instance.buses
            _add_bus!(model, b)
        end
        for g in instance.units
            _add_unit!(model, g)
        end
        for ps in instance.price_sensitive_loads
            _add_price_sensitive_load!(model, ps)
        end
        _build_net_injection_eqs!(model)
        _build_reserve_eqs!(model)
        _build_obj_function!(model)
    end
    @info @sprintf("Built model in %.2f seconds", time_model)

    if variable_names
        _set_names!(model)
    end

    return model
end

function _add_transmission_line!(model, lm)
    obj, T = model[:obj], model[:instance].time
    overflow = model[:overflow]
    for t in 1:T
        v = overflow[lm.name, t] = @variable(model, lower_bound = 0)
        add_to_expression!(obj, v, lm.flow_limit_penalty[t])
    end
end

function _add_bus!(model::JuMP.Model, b::Bus)
    mip = model
    net_injection = model[:expr_net_injection]
    reserve = model[:expr_reserve]
    curtail = model[:curtail]
    for t in 1:model[:instance].time
        # Fixed load
        net_injection[b.name, t] = AffExpr(-b.load[t])

        # Reserves
        reserve[b.name, t] = AffExpr()

        # Load curtailment
        curtail[b.name, t] =
            @variable(mip, lower_bound = 0, upper_bound = b.load[t])
        add_to_expression!(net_injection[b.name, t], curtail[b.name, t], 1.0)
        add_to_expression!(
            model[:obj],
            curtail[b.name, t],
            model[:instance].power_balance_penalty[t],
        )
    end
end

function _add_price_sensitive_load!(model::JuMP.Model, ps::PriceSensitiveLoad)
    mip = model
    loads = model[:loads]
    net_injection = model[:expr_net_injection]
    for t in 1:model[:instance].time
        # Decision variable
        loads[ps.name, t] =
            @variable(mip, lower_bound = 0, upper_bound = ps.demand[t])

        # Objective function terms
        add_to_expression!(model[:obj], loads[ps.name, t], -ps.revenue[t])

        # Net injection
        add_to_expression!(
            net_injection[ps.bus.name, t],
            loads[ps.name, t],
            -1.0,
        )
    end
end

function _add_unit!(model::JuMP.Model, g::Unit)
    mip, T = model, model[:instance].time
    gi, K, S = g.name, length(g.cost_segments), length(g.startup_categories)

    segprod = model[:segprod]
    prod_above = model[:prod_above]
    reserve = model[:reserve]
    startup = model[:startup]
    is_on = model[:is_on]
    switch_on = model[:switch_on]
    switch_off = model[:switch_off]
    expr_net_injection = model[:expr_net_injection]
    expr_reserve = model[:expr_reserve]

    if !all(g.must_run) && any(g.must_run)
        error("Partially must-run units are not currently supported")
    end

    if g.initial_power === nothing || g.initial_status === nothing
        error("Initial conditions for $(g.name) must be provided")
    end

    is_initially_on = (g.initial_status > 0 ? 1.0 : 0.0)

    # Decision variables
    for t in 1:T
        for k in 1:K
            segprod[gi, t, k] = @variable(model, lower_bound = 0)
        end
        prod_above[gi, t] = @variable(model, lower_bound = 0)
        if g.provides_spinning_reserves[t]
            reserve[gi, t] = @variable(model, lower_bound = 0)
        else
            reserve[gi, t] = 0.0
        end
        for s in 1:S
            startup[gi, t, s] = @variable(model, binary = true)
        end
        if g.must_run[t]
            is_on[gi, t] = 1.0
            switch_on[gi, t] = (t == 1 ? 1.0 - is_initially_on : 0.0)
            switch_off[gi, t] = 0.0
        else
            is_on[gi, t] = @variable(model, binary = true)
            switch_on[gi, t] = @variable(model, binary = true)
            switch_off[gi, t] = @variable(model, binary = true)
        end
    end

    for t in 1:T
        # Time-dependent start-up costs
        for s in 1:S
            # If unit is switching on, we must choose a startup category
            model[:eq_startup_choose][gi, t, s] = @constraint(
                mip,
                switch_on[gi, t] == sum(startup[gi, t, s] for s in 1:S)
            )

            # If unit has not switched off in the last `delay` time periods, startup category is forbidden.
            # The last startup category is always allowed.
            if s < S
                range_start = t - g.startup_categories[s+1].delay + 1
                range_end = t - g.startup_categories[s].delay
                range = (range_start:range_end)
                initial_sum = (
                    g.initial_status < 0 && (g.initial_status + 1 in range) ? 1.0 : 0.0
                )
                model[:eq_startup_restrict][gi, t, s] = @constraint(
                    mip,
                    startup[gi, t, s] <=
                    initial_sum +
                    sum(switch_off[gi, i] for i in range if i >= 1)
                )
            end

            # Objective function terms for start-up costs
            add_to_expression!(
                model[:obj],
                startup[gi, t, s],
                g.startup_categories[s].cost,
            )
        end

        # Objective function terms for production costs
        add_to_expression!(model[:obj], is_on[gi, t], g.min_power_cost[t])
        for k in 1:K
            add_to_expression!(
                model[:obj],
                segprod[gi, t, k],
                g.cost_segments[k].cost[t],
            )
        end

        # Production limits (piecewise-linear segments)
        for k in 1:K
            model[:eq_segprod_limit][gi, t, k] = @constraint(
                mip,
                segprod[gi, t, k] <= g.cost_segments[k].mw[t] * is_on[gi, t]
            )
        end

        # Definition of production
        model[:eq_prod_above_def][gi, t] = @constraint(
            mip,
            prod_above[gi, t] == sum(segprod[gi, t, k] for k in 1:K)
        )

        # Production limit
        model[:eq_prod_limit][gi, t] = @constraint(
            mip,
            prod_above[gi, t] + reserve[gi, t] <=
            (g.max_power[t] - g.min_power[t]) * is_on[gi, t]
        )

        # Binary variable equations for economic units
        if !g.must_run[t]

            # Link binary variables
            if t == 1
                model[:eq_binary_link][gi, t] = @constraint(
                    mip,
                    is_on[gi, t] - is_initially_on ==
                    switch_on[gi, t] - switch_off[gi, t]
                )
            else
                model[:eq_binary_link][gi, t] = @constraint(
                    mip,
                    is_on[gi, t] - is_on[gi, t-1] ==
                    switch_on[gi, t] - switch_off[gi, t]
                )
            end

            # Cannot switch on and off at the same time
            model[:eq_switch_on_off][gi, t] =
                @constraint(mip, switch_on[gi, t] + switch_off[gi, t] <= 1)
        end

        # Ramp up limit
        if t == 1
            if is_initially_on == 1
                model[:eq_ramp_up][gi, t] = @constraint(
                    mip,
                    prod_above[gi, t] + reserve[gi, t] <=
                    (g.initial_power - g.min_power[t]) + g.ramp_up_limit
                )
            end
        else
            model[:eq_ramp_up][gi, t] = @constraint(
                mip,
                prod_above[gi, t] + reserve[gi, t] <=
                prod_above[gi, t-1] + g.ramp_up_limit
            )
        end

        # Ramp down limit
        if t == 1
            if is_initially_on == 1
                model[:eq_ramp_down][gi, t] = @constraint(
                    mip,
                    prod_above[gi, t] >=
                    (g.initial_power - g.min_power[t]) - g.ramp_down_limit
                )
            end
        else
            model[:eq_ramp_down][gi, t] = @constraint(
                mip,
                prod_above[gi, t] >= prod_above[gi, t-1] - g.ramp_down_limit
            )
        end

        # Startup limit
        model[:eq_startup_limit][gi, t] = @constraint(
            mip,
            prod_above[gi, t] + reserve[gi, t] <=
            (g.max_power[t] - g.min_power[t]) * is_on[gi, t] -
            max(0, g.max_power[t] - g.startup_limit) * switch_on[gi, t]
        )

        # Shutdown limit
        if g.initial_power > g.shutdown_limit
            model[:eq_shutdown_limit][gi, 0] =
                @constraint(mip, switch_off[gi, 1] <= 0)
        end
        if t < T
            model[:eq_shutdown_limit][gi, t] = @constraint(
                mip,
                prod_above[gi, t] <=
                (g.max_power[t] - g.min_power[t]) * is_on[gi, t] -
                max(0, g.max_power[t] - g.shutdown_limit) * switch_off[gi, t+1]
            )
        end

        # Minimum up-time
        model[:eq_min_uptime][gi, t] = @constraint(
            mip,
            sum(switch_on[gi, i] for i in (t-g.min_uptime+1):t if i >= 1) <=
            is_on[gi, t]
        )

        # # Minimum down-time
        model[:eq_min_downtime][gi, t] = @constraint(
            mip,
            sum(switch_off[gi, i] for i in (t-g.min_downtime+1):t if i >= 1) <= 1 - is_on[gi, t]
        )

        # Minimum up/down-time for initial periods
        if t == 1
            if g.initial_status > 0
                model[:eq_min_uptime][gi, 0] = @constraint(
                    mip,
                    sum(
                        switch_off[gi, i] for
                        i in 1:(g.min_uptime-g.initial_status) if i <= T
                    ) == 0
                )
            else
                model[:eq_min_downtime][gi, 0] = @constraint(
                    mip,
                    sum(
                        switch_on[gi, i] for
                        i in 1:(g.min_downtime+g.initial_status) if i <= T
                    ) == 0
                )
            end
        end

        # Add to net injection expression
        add_to_expression!(
            expr_net_injection[g.bus.name, t],
            prod_above[g.name, t],
            1.0,
        )
        add_to_expression!(
            expr_net_injection[g.bus.name, t],
            is_on[g.name, t],
            g.min_power[t],
        )

        # Add to reserves expression
        add_to_expression!(expr_reserve[g.bus.name, t], reserve[gi, t], 1.0)
    end
end

function _build_obj_function!(model::JuMP.Model)
    @objective(model, Min, model[:obj])
end

function _build_net_injection_eqs!(model::JuMP.Model)
    T = model[:instance].time
    net_injection = model[:net_injection]
    for t in 1:T, b in model[:instance].buses
        n = net_injection[b.name, t] = @variable(model)
        model[:eq_net_injection_def][t, b.name] =
            @constraint(model, n == model[:expr_net_injection][b.name, t])
    end
    for t in 1:T
        model[:eq_power_balance][t] = @constraint(
            model,
            sum(net_injection[b.name, t] for b in model[:instance].buses) == 0
        )
    end
end

function _build_reserve_eqs!(model::JuMP.Model)
    reserves = model[:instance].reserves
    for t in 1:model[:instance].time
        model[:eq_min_reserve][t] = @constraint(
            model,
            sum(
                model[:expr_reserve][b.name, t] for b in model[:instance].buses
            ) >= reserves.spinning[t]
        )
    end
end

function _enforce_transmission(;
    model::JuMP.Model,
    violation::Violation,
    isf::Matrix{Float64},
    lodf::Matrix{Float64},
)::Nothing
    instance = model[:instance]
    limit::Float64 = 0.0
    overflow = model[:overflow]
    net_injection = model[:net_injection]

    if violation.outage_line === nothing
        limit = violation.monitored_line.normal_flow_limit[violation.time]
        @info @sprintf(
            "    %8.3f MW overflow in %-5s time %3d (pre-contingency)",
            violation.amount,
            violation.monitored_line.name,
            violation.time,
        )
    else
        limit = violation.monitored_line.emergency_flow_limit[violation.time]
        @info @sprintf(
            "    %8.3f MW overflow in %-5s time %3d (outage: line %s)",
            violation.amount,
            violation.monitored_line.name,
            violation.time,
            violation.outage_line.name,
        )
    end

    fm = violation.monitored_line.name
    t = violation.time
    flow = @variable(model, base_name = "flow[$fm,$t]")

    v = overflow[violation.monitored_line.name, violation.time]
    @constraint(model, flow <= limit + v)
    @constraint(model, -flow <= limit + v)

    if violation.outage_line === nothing
        @constraint(
            model,
            flow == sum(
                net_injection[b.name, violation.time] *
                isf[violation.monitored_line.offset, b.offset] for
                b in instance.buses if b.offset > 0
            )
        )
    else
        @constraint(
            model,
            flow == sum(
                net_injection[b.name, violation.time] * (
                    isf[violation.monitored_line.offset, b.offset] + (
                        lodf[
                            violation.monitored_line.offset,
                            violation.outage_line.offset,
                        ] * isf[violation.outage_line.offset, b.offset]
                    )
                ) for b in instance.buses if b.offset > 0
            )
        )
    end
    return nothing
end

function _set_names!(model::JuMP.Model)
    @info "Setting variable and constraint names..."
    time_varnames = @elapsed begin
        _set_names!(object_dictionary(model))
    end
    @info @sprintf("Set names in %.2f seconds", time_varnames)
end

function _set_names!(dict::Dict)
    for name in keys(dict)
        dict[name] isa AbstractDict || continue
        for idx in keys(dict[name])
            if dict[name][idx] isa AffExpr
                continue
            end
            idx_str = join(map(string, idx), ",")
            set_name(dict[name][idx], "$name[$idx_str]")
        end
    end
end

function solution(model::JuMP.Model)
    instance, T = model[:instance], model[:instance].time
    function timeseries(vars, collection)
        return OrderedDict(
            b.name => [round(value(vars[b.name, t]), digits = 5) for t in 1:T]
            for b in collection
        )
    end
    function production_cost(g)
        return [
            value(model[:is_on][g.name, t]) * g.min_power_cost[t] + sum(
                Float64[
                    value(model[:segprod][g.name, t, k]) *
                    g.cost_segments[k].cost[t] for
                    k in 1:length(g.cost_segments)
                ],
            ) for t in 1:T
        ]
    end
    function production(g)
        return [
            value(model[:is_on][g.name, t]) * g.min_power[t] + sum(
                Float64[
                    value(model[:segprod][g.name, t, k]) for
                    k in 1:length(g.cost_segments)
                ],
            ) for t in 1:T
        ]
    end
    function startup_cost(g)
        S = length(g.startup_categories)
        return [
            sum(
                g.startup_categories[s].cost *
                value(model[:startup][g.name, t, s]) for s in 1:S
            ) for t in 1:T
        ]
    end
    sol = OrderedDict()
    sol["Production (MW)"] =
        OrderedDict(g.name => production(g) for g in instance.units)
    sol["Production cost (\$)"] =
        OrderedDict(g.name => production_cost(g) for g in instance.units)
    sol["Startup cost (\$)"] =
        OrderedDict(g.name => startup_cost(g) for g in instance.units)
    sol["Is on"] = timeseries(model[:is_on], instance.units)
    sol["Switch on"] = timeseries(model[:switch_on], instance.units)
    sol["Switch off"] = timeseries(model[:switch_off], instance.units)
    sol["Reserve (MW)"] = timeseries(model[:reserve], instance.units)
    sol["Net injection (MW)"] =
        timeseries(model[:net_injection], instance.buses)
    sol["Load curtail (MW)"] = timeseries(model[:curtail], instance.buses)
    if !isempty(instance.lines)
        sol["Line overflow (MW)"] = timeseries(model[:overflow], instance.lines)
    end
    if !isempty(instance.price_sensitive_loads)
        sol["Price-sensitive loads (MW)"] =
            timeseries(model[:loads], instance.price_sensitive_loads)
    end
    return sol
end

function write(filename::AbstractString, solution::AbstractDict)::Nothing
    open(filename, "w") do file
        return JSON.print(file, solution, 2)
    end
    return
end

function fix!(model::JuMP.Model, solution::AbstractDict)::Nothing
    instance, T = model[:instance], model[:instance].time
    is_on = model[:is_on]
    prod_above = model[:prod_above]
    reserve = model[:reserve]
    for g in instance.units
        for t in 1:T
            is_on_value = round(solution["Is on"][g.name][t])
            production_value =
                round(solution["Production (MW)"][g.name][t], digits = 5)
            reserve_value =
                round(solution["Reserve (MW)"][g.name][t], digits = 5)
            JuMP.fix(is_on[g.name, t], is_on_value, force = true)
            JuMP.fix(
                prod_above[g.name, t],
                production_value - is_on_value * g.min_power[t],
                force = true,
            )
            JuMP.fix(reserve[g.name, t], reserve_value, force = true)
        end
    end
    return
end

function set_warm_start!(model::JuMP.Model, solution::AbstractDict)::Nothing
    instance, T = model[:instance], model[:instance].time
    is_on = model[:is_on]
    prod_above = model[:prod_above]
    reserve = model[:reserve]
    for g in instance.units
        for t in 1:T
            JuMP.set_start_value(is_on[g.name, t], solution["Is on"][g.name][t])
            JuMP.set_start_value(
                switch_on[g.name, t],
                solution["Switch on"][g.name][t],
            )
            JuMP.set_start_value(
                switch_off[g.name, t],
                solution["Switch off"][g.name][t],
            )
        end
    end
    return
end

function optimize!(
    model::JuMP.Model;
    time_limit = 3600,
    gap_limit = 1e-4,
    two_phase_gap = true,
)::Nothing
    function set_gap(gap)
        try
            JuMP.set_optimizer_attribute(model, "MIPGap", gap)
            @info @sprintf("MIP gap tolerance set to %f", gap)
        catch
            @warn "Could not change MIP gap tolerance"
        end
    end

    instance = model[:instance]
    initial_time = time()

    large_gap = false
    has_transmission = (length(model[:isf]) > 0)

    if has_transmission && two_phase_gap
        set_gap(1e-2)
        large_gap = true
    else
        set_gap(gap_limit)
    end

    while true
        time_elapsed = time() - initial_time
        time_remaining = time_limit - time_elapsed
        if time_remaining < 0
            @info "Time limit exceeded"
            break
        end

        @info @sprintf(
            "Setting MILP time limit to %.2f seconds",
            time_remaining
        )
        JuMP.set_time_limit_sec(model, time_remaining)

        @info "Solving MILP..."
        JuMP.optimize!(model)

        has_transmission || break

        violations = _find_violations(model)
        if isempty(violations)
            @info "No violations found"
            if large_gap
                large_gap = false
                set_gap(gap_limit)
            else
                break
            end
        else
            _enforce_transmission(model, violations)
        end
    end

    return
end

function _find_violations(model::JuMP.Model)
    instance = model[:instance]
    net_injection = model[:net_injection]
    overflow = model[:overflow]
    length(instance.buses) > 1 || return []
    violations = []
    @info "Verifying transmission limits..."
    time_screening = @elapsed begin
        non_slack_buses = [b for b in instance.buses if b.offset > 0]
        net_injection_values = [
            value(net_injection[b.name, t]) for b in non_slack_buses,
            t in 1:instance.time
        ]
        overflow_values = [
            value(overflow[lm.name, t]) for lm in instance.lines,
            t in 1:instance.time
        ]
        violations = UnitCommitment._find_violations(
            instance = instance,
            net_injections = net_injection_values,
            overflow = overflow_values,
            isf = model[:isf],
            lodf = model[:lodf],
        )
    end
    @info @sprintf(
        "Verified transmission limits in %.2f seconds",
        time_screening
    )
    return violations
end

function _enforce_transmission(
    model::JuMP.Model,
    violations::Vector{Violation},
)::Nothing
    for v in violations
        _enforce_transmission(
            model = model,
            violation = v,
            isf = model[:isf],
            lodf = model[:lodf],
        )
    end
    return
end

export build_model
