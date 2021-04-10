# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using JuMP, MathOptInterface, DataStructures
import JuMP: value, fix, set_name


# Extend some JuMP functions so that decision variables can be safely replaced by
# (constant) floating point numbers.
function value(x::Float64)
    x
end

function fix(x::Float64, v::Float64; force)
    abs(x - v) < 1e-6 || error("Value mismatch: $x != $v")
end

function set_name(x::Float64, n::String)
    # nop
end


mutable struct UnitCommitmentModel
    mip::JuMP.Model
    vars::DotDict
    eqs::DotDict
    exprs::DotDict
    instance::UnitCommitmentInstance
    isf::Matrix{Float64}
    lodf::Matrix{Float64}
    obj::AffExpr
end


function build_model(;
                     filename::Union{String, Nothing}=nothing,
                     instance::Union{UnitCommitmentInstance, Nothing}=nothing,
                     isf::Union{Array{Float64,2}, Nothing}=nothing,
                     lodf::Union{Array{Float64,2}, Nothing}=nothing,
                     isf_cutoff::Float64=0.005,
                     lodf_cutoff::Float64=0.001,
                     optimizer=nothing,
                     model=nothing,
                     variable_names::Bool=false,
                    ) :: UnitCommitmentModel

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
                isf = UnitCommitment.injection_shift_factors(lines=instance.lines,
                                                             buses=instance.buses)
            end
            @info @sprintf("Computed ISF in %.2f seconds", time_isf)
            
            @info "Computing line outage factors..."
            time_lodf = @elapsed begin
                lodf = UnitCommitment.line_outage_factors(lines=instance.lines,
                                                          buses=instance.buses,
                                                          isf=isf)
            end
            @info @sprintf("Computed LODF in %.2f seconds", time_lodf)
            
            @info @sprintf("Applying PTDF and LODF cutoffs (%.5f, %.5f)", isf_cutoff, lodf_cutoff)
            isf[abs.(isf) .< isf_cutoff] .= 0
            lodf[abs.(lodf) .< lodf_cutoff] .= 0
        end
    end

    @info "Building model..."
    time_model = @elapsed begin
        if model === nothing
            if optimizer === nothing
                mip = Model()
            else
                mip = Model(optimizer)
            end
        else
            mip = model
        end
        model = UnitCommitmentModel(mip,
                                    DotDict(),  # vars
                                    DotDict(),  # eqs
                                    DotDict(),  # exprs
                                    instance,
                                    isf,
                                    lodf,
                                    AffExpr(),  # obj
                                   )
        for field in [:prod_above, :segprod, :reserve, :is_on, :switch_on, :switch_off,
                      :net_injection, :curtail, :overflow, :loads, :startup]
            setproperty!(model.vars, field, OrderedDict())
        end
        for field in [:startup_choose, :startup_restrict, :segprod_limit, :prod_above_def,
                      :prod_limit, :binary_link, :switch_on_off, :ramp_up, :ramp_down,
                      :startup_limit, :shutdown_limit, :min_uptime, :min_downtime, :power_balance,
                      :net_injection_def, :min_reserve]
            setproperty!(model.eqs, field, OrderedDict())
        end
        for field in [:inj, :reserve, :net_injection]
            setproperty!(model.exprs, field, OrderedDict())
        end
        for lm in instance.lines
            add_transmission_line!(model, lm)
        end
        for b in instance.buses
            add_bus!(model, b)
        end
        for g in instance.units
            add_unit!(model, g)
        end
        for ps in instance.price_sensitive_loads
            add_price_sensitive_load!(model, ps)
        end
        build_net_injection_eqs!(model)
        build_reserve_eqs!(model)
        build_obj_function!(model)
    end
    @info @sprintf("Built model in %.2f seconds", time_model)

    if variable_names
        set_variable_names!(model)
    end
    
    return model
end


function add_transmission_line!(model, lm)
    vars, obj, T = model.vars, model.obj, model.instance.time
    for t in 1:T
        overflow = vars.overflow[lm.name, t] = @variable(model.mip, lower_bound=0)
        add_to_expression!(obj, overflow, lm.flow_limit_penalty[t])
    end
end


function add_bus!(model::UnitCommitmentModel, b::Bus)
    mip, vars, exprs = model.mip, model.vars, model.exprs
    for t in 1:model.instance.time
        # Fixed load
        exprs.net_injection[b.name, t] = AffExpr(-b.load[t])
        
        # Reserves
        exprs.reserve[b.name, t] = AffExpr()

         # Load curtailment
        vars.curtail[b.name, t] = @variable(mip, lower_bound=0, upper_bound=b.load[t])
        add_to_expression!(exprs.net_injection[b.name, t], vars.curtail[b.name, t], 1.0)
        add_to_expression!(model.obj,
                           vars.curtail[b.name, t],
                           model.instance.power_balance_penalty[t])
    end
end


function add_price_sensitive_load!(model::UnitCommitmentModel, ps::PriceSensitiveLoad)
    mip, vars = model.mip, model.vars
    for t in 1:model.instance.time
        # Decision variable
        vars.loads[ps.name, t] = @variable(mip, lower_bound=0, upper_bound=ps.demand[t])
        
        # Objective function terms
        add_to_expression!(model.obj, vars.loads[ps.name, t], -ps.revenue[t])
        
        # Net injection
        add_to_expression!(model.exprs.net_injection[ps.bus.name, t], vars.loads[ps.name, t], -1.0)
    end
end


function add_unit!(model::UnitCommitmentModel, g::Unit)
    mip, vars, eqs, exprs, T = model.mip, model.vars, model.eqs, model.exprs, model.instance.time
    gi, K, S = g.name, length(g.cost_segments), length(g.startup_categories)
    
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
            model.vars.segprod[gi, t, k] = @variable(model.mip, lower_bound=0)
        end
        model.vars.prod_above[gi, t] = @variable(model.mip, lower_bound=0)
        if g.provides_spinning_reserves[t]
            model.vars.reserve[gi, t] = @variable(model.mip, lower_bound=0)
        else
            model.vars.reserve[gi, t] = 0.0
        end
        for s in 1:S
            model.vars.startup[gi, t, s] = @variable(model.mip, binary=true)
        end
        if g.must_run[t]
            model.vars.is_on[gi, t] = 1.0
            model.vars.switch_on[gi, t] = (t == 1 ? 1.0 - is_initially_on : 0.0)
            model.vars.switch_off[gi, t] = 0.0
        else
            model.vars.is_on[gi, t] = @variable(model.mip, binary=true)
            model.vars.switch_on[gi, t] = @variable(model.mip, binary=true)
            model.vars.switch_off[gi, t] = @variable(model.mip, binary=true)
        end
    end

    for t in 1:T
        # Time-dependent start-up costs
        for s in 1:S
            # If unit is switching on, we must choose a startup category
            eqs.startup_choose[gi, t, s] =
                @constraint(mip, vars.switch_on[gi, t] == sum(vars.startup[gi, t, s] for s in 1:S))
            
            # If unit has not switched off in the last `delay` time periods, startup category is forbidden.
            # The last startup category is always allowed.
            if s < S
                range = (t - g.startup_categories[s + 1].delay + 1):(t - g.startup_categories[s].delay)
                initial_sum = (g.initial_status < 0 && (g.initial_status + 1 in range) ? 1.0 : 0.0)
                eqs.startup_restrict[gi, t, s] =
                    @constraint(mip, vars.startup[gi, t, s]
                                        <= initial_sum + sum(vars.switch_off[gi, i] for i in range if i >= 1))
            end
            
            # Objective function terms for start-up costs
            add_to_expression!(model.obj,
                               vars.startup[gi, t, s],
                               g.startup_categories[s].cost)
        end
        
        # Objective function terms for production costs
        add_to_expression!(model.obj, vars.is_on[gi, t], g.min_power_cost[t])
        for k in 1:K
            add_to_expression!(model.obj, vars.segprod[gi, t, k], g.cost_segments[k].cost[t])
        end

        # Production limits (piecewise-linear segments)
        for k in 1:K
            eqs.segprod_limit[gi, t, k] =
                @constraint(mip, vars.segprod[gi, t, k] <= g.cost_segments[k].mw[t] * vars.is_on[gi, t])
        end

        # Definition of production
        eqs.prod_above_def[gi, t] =
            @constraint(mip, vars.prod_above[gi, t] == sum(vars.segprod[gi, t, k] for k in 1:K))

        # Production limit
        eqs.prod_limit[gi, t] =
            @constraint(mip,
                        vars.prod_above[gi, t] + vars.reserve[gi, t]
                                <= (g.max_power[t] - g.min_power[t]) * vars.is_on[gi, t])

        # Binary variable equations for economic units
        if !g.must_run[t]
            
            # Link binary variables
            if t == 1
                eqs.binary_link[gi, t] =
                    @constraint(mip,
                                vars.is_on[gi, t] - is_initially_on ==
                                    vars.switch_on[gi, t] - vars.switch_off[gi, t])
            else
                eqs.binary_link[gi, t] =
                    @constraint(mip,
                                vars.is_on[gi, t] - vars.is_on[gi, t-1] ==
                                    vars.switch_on[gi, t] - vars.switch_off[gi, t])
            end

            # Cannot switch on and off at the same time
            eqs.switch_on_off[gi, t] =
                @constraint(mip, vars.switch_on[gi, t] + vars.switch_off[gi, t] <= 1)
        end
        
        # Ramp up limit
        if t == 1
            if is_initially_on == 1
                eqs.ramp_up[gi, t] =
                    @constraint(mip,
                                vars.prod_above[gi, t] + vars.reserve[gi, t] <=
                                        (g.initial_power - g.min_power[t]) + g.ramp_up_limit)
            end
        else
            eqs.ramp_up[gi, t] = 
                @constraint(mip,
                            vars.prod_above[gi, t] + vars.reserve[gi, t] <=
                                    vars.prod_above[gi, t-1] + g.ramp_up_limit)
        end
        
        # Ramp down limit
        if t == 1
            if is_initially_on == 1
                eqs.ramp_down[gi, t] =
                    @constraint(mip,
                                vars.prod_above[gi, t] >=
                                        (g.initial_power - g.min_power[t]) - g.ramp_down_limit)
            end
        else
            eqs.ramp_down[gi, t] =
                @constraint(mip,
                            vars.prod_above[gi, t] >=
                                vars.prod_above[gi, t-1] - g.ramp_down_limit)
        end
        
        # Startup limit
        eqs.startup_limit[gi, t] = 
            @constraint(mip,
                        vars.prod_above[gi, t] + vars.reserve[gi, t] <=
                            (g.max_power[t] - g.min_power[t]) * vars.is_on[gi, t]
                            - max(0, g.max_power[t] - g.startup_limit) * vars.switch_on[gi, t])
        
        # Shutdown limit
        if g.initial_power > g.shutdown_limit
            eqs.shutdown_limit[gi, 0] = 
                @constraint(mip, vars.switch_off[gi, 1] <= 0)
        end
        if t < T
            eqs.shutdown_limit[gi, t] =
                @constraint(mip,
                            vars.prod_above[gi, t] <=
                                (g.max_power[t] - g.min_power[t]) * vars.is_on[gi, t]
                                - max(0, g.max_power[t] - g.shutdown_limit) * vars.switch_off[gi, t+1])
        end
        
        # Minimum up-time
        eqs.min_uptime[gi, t] =
            @constraint(mip, 
                        sum(vars.switch_on[gi, i]
                            for i in (t - g.min_uptime + 1):t if i >= 1
                           ) <= vars.is_on[gi, t])
        
        # # Minimum down-time
        eqs.min_downtime[gi, t] =
            @constraint(mip,
                        sum(vars.switch_off[gi, i]
                            for i in (t - g.min_downtime + 1):t if i >= 1
                           ) <= 1 - vars.is_on[gi, t])
        
        # Minimum up/down-time for initial periods
        if t == 1
            if g.initial_status > 0
                eqs.min_uptime[gi, 0] =
                    @constraint(mip, sum(vars.switch_off[gi, i]
                                         for i in 1:(g.min_uptime - g.initial_status) if i <= T) == 0)
            else
                eqs.min_downtime[gi, 0] =
                    @constraint(mip, sum(vars.switch_on[gi, i]
                                         for i in 1:(g.min_downtime + g.initial_status) if i <= T) == 0)
            end
        end
        
        # Add to net injection expression
        add_to_expression!(exprs.net_injection[g.bus.name, t], vars.prod_above[g.name, t], 1.0)
        add_to_expression!(exprs.net_injection[g.bus.name, t], vars.is_on[g.name, t], g.min_power[t])
        
        # Add to reserves expression
        add_to_expression!(exprs.reserve[g.bus.name, t], vars.reserve[gi, t], 1.0)
    end
end


function build_obj_function!(model::UnitCommitmentModel)
    @objective(model.mip, Min, model.obj)
end


function build_net_injection_eqs!(model::UnitCommitmentModel)
    T = model.instance.time
    for t in 1:T, b in model.instance.buses
        net = model.vars.net_injection[b.name, t] = @variable(model.mip)
        model.eqs.net_injection_def[t, b.name] =
            @constraint(model.mip, net == model.exprs.net_injection[b.name, t])
    end
    for t in 1:T
        model.eqs.power_balance[t] =
            @constraint(model.mip, sum(model.vars.net_injection[b.name, t]
                                       for b in model.instance.buses) == 0)
    end
end


function build_reserve_eqs!(model::UnitCommitmentModel)
    reserves = model.instance.reserves
    for t in 1:model.instance.time
        model.eqs.min_reserve[t] =
            @constraint(model.mip, sum(model.exprs.reserve[b.name, t]
                                       for b in model.instance.buses) >= reserves.spinning[t])
    end
end


function enforce_transmission(;
                              model::UnitCommitmentModel,
                              violation::Violation,
                              isf::Matrix{Float64},
                              lodf::Matrix{Float64})::Nothing

    instance, mip, vars = model.instance, model.mip, model.vars
    limit::Float64 = 0.0
        
    if violation.outage_line === nothing
        limit = violation.monitored_line.normal_flow_limit[violation.time]
        @info @sprintf("    %8.3f MW overflow in %-5s time %3d (pre-contingency)",
                       violation.amount,
                       violation.monitored_line.name,
                       violation.time)
    else
        limit = violation.monitored_line.emergency_flow_limit[violation.time]
        @info @sprintf("    %8.3f MW overflow in %-5s time %3d (outage: line %s)",
                       violation.amount,
                       violation.monitored_line.name,
                       violation.time,
                       violation.outage_line.name)
    end
    
    fm = violation.monitored_line.name
    t = violation.time
    flow = @variable(mip, base_name="flow[$fm,$t]")
    
    overflow = vars.overflow[violation.monitored_line.name, violation.time]
    @constraint(mip, flow  <= limit + overflow)
    @constraint(mip, -flow <= limit + overflow)
    
    if violation.outage_line === nothing
        @constraint(mip, flow == sum(vars.net_injection[b.name, violation.time] *
                                         isf[violation.monitored_line.offset, b.offset]
                                     for b in instance.buses
                                     if b.offset > 0))
    else
        @constraint(mip, flow == sum(vars.net_injection[b.name, violation.time] * (
                                         isf[violation.monitored_line.offset, b.offset] + (
                                             lodf[violation.monitored_line.offset, violation.outage_line.offset] *
                                             isf[violation.outage_line.offset, b.offset]
                                         )
                                     )
                                     for b in instance.buses
                                     if b.offset > 0))
    end
    nothing
end


function set_variable_names!(model::UnitCommitmentModel)
    @info "Setting variable and constraint names..."
    time_varnames = @elapsed begin
        set_jump_names!(model.vars)
        set_jump_names!(model.eqs)
    end
    @info @sprintf("Set names in %.2f seconds", time_varnames)
end


function set_jump_names!(dict)
    for name in keys(dict)
        for idx in keys(dict[name])
            idx_str = join(map(string, idx), ",")
            set_name(dict[name][idx], "$name[$idx_str]")
        end
    end
end


function get_solution(model::UnitCommitmentModel)
    instance, T = model.instance, model.instance.time
    function timeseries(vars, collection)
        return OrderedDict(b.name => [round(value(vars[b.name, t]), digits=5) for t in 1:T]
                           for b in collection)
    end
    function production_cost(g)
        return [value(model.vars.is_on[g.name, t]) * g.min_power_cost[t] +
                sum(Float64[value(model.vars.segprod[g.name, t, k]) * g.cost_segments[k].cost[t]
                            for k in 1:length(g.cost_segments)])
                for t in 1:T]
    end
    function production(g)
        return [value(model.vars.is_on[g.name, t]) * g.min_power[t] +
                sum(Float64[value(model.vars.segprod[g.name, t, k])
                            for k in 1:length(g.cost_segments)])
                for t in 1:T]
    end
    function startup_cost(g)
        S = length(g.startup_categories)
        return [sum(g.startup_categories[s].cost * value(model.vars.startup[g.name, t, s])
                    for s in 1:S)
                for t in 1:T]
    end
    sol = OrderedDict()
    sol["Production (MW)"] = OrderedDict(g.name => production(g) for g in instance.units)
    sol["Production cost (\$)"] = OrderedDict(g.name => production_cost(g) for g in instance.units)
    sol["Startup cost (\$)"] = OrderedDict(g.name => startup_cost(g) for g in instance.units)
    sol["Is on"] = timeseries(model.vars.is_on, instance.units)
    sol["Switch on"] = timeseries(model.vars.switch_on, instance.units)
    sol["Switch off"] = timeseries(model.vars.switch_off, instance.units)
    sol["Reserve (MW)"] = timeseries(model.vars.reserve, instance.units)
    sol["Net injection (MW)"] = timeseries(model.vars.net_injection, instance.buses)
    sol["Load curtail (MW)"] = timeseries(model.vars.curtail, instance.buses)
    if !isempty(instance.lines)
        sol["Line overflow (MW)"] = timeseries(model.vars.overflow, instance.lines)
    end
    if !isempty(instance.price_sensitive_loads)
        sol["Price-sensitive loads (MW)"] = timeseries(model.vars.loads, instance.price_sensitive_loads)
    end
    return sol
end


function fix!(model::UnitCommitmentModel, solution)::Nothing
    vars, instance, T = model.vars, model.instance, model.instance.time
    for g in instance.units
        for t in 1:T
            is_on = round(solution["Is on"][g.name][t])
            production = round(solution["Production (MW)"][g.name][t], digits=5)
            reserve = round(solution["Reserve (MW)"][g.name][t], digits=5)
            JuMP.fix(vars.is_on[g.name, t], is_on, force=true)
            JuMP.fix(vars.prod_above[g.name, t], production - is_on * g.min_power[t], force=true)
            JuMP.fix(vars.reserve[g.name, t], reserve, force=true)
        end
    end
end


function set_warm_start!(model::UnitCommitmentModel, solution)::Nothing
    vars, instance, T = model.vars, model.instance, model.instance.time
    for g in instance.units
        for t in 1:T
            JuMP.set_start_value(vars.is_on[g.name, t], solution["Is on"][g.name][t])
            JuMP.set_start_value(vars.switch_on[g.name, t], solution["Switch on"][g.name][t])
            JuMP.set_start_value(vars.switch_off[g.name, t], solution["Switch off"][g.name][t])
        end
    end
end


function optimize!(model::UnitCommitmentModel;
                   time_limit=3600,
                   gap_limit=1e-4,
                   two_phase_gap=true,
                   )::Nothing
    
    function set_gap(gap)
        try
            JuMP.set_optimizer_attribute(model.mip, "MIPGap", gap)
            @info @sprintf("MIP gap tolerance set to %f", gap)
        catch
            @warn "Could not change MIP gap tolerance"
        end
    end
    
    instance = model.instance
    initial_time = time()
    
    large_gap = false
    has_transmission = (length(model.isf) > 0)
    
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
        
        @info @sprintf("Setting MILP time limit to %.2f seconds", time_remaining)
        JuMP.set_time_limit_sec(model.mip, time_remaining)
        
        @info "Solving MILP..."
        JuMP.optimize!(model.mip)
        
        has_transmission || break
        
        violations = find_violations(model)
        if isempty(violations)
            @info "No violations found" 
            if large_gap
                large_gap = false
                set_gap(gap_limit)
            else
                break
            end
        else
            enforce_transmission(model, violations)
        end
    end
    
    nothing
end


function find_violations(model::UnitCommitmentModel)
    instance, vars = model.instance, model.vars
    length(instance.buses) > 1 || return []
    violations = []
    @info "Verifying transmission limits..."
    time_screening = @elapsed begin
        non_slack_buses = [b for b in instance.buses if b.offset > 0]
        net_injections = [value(vars.net_injection[b.name, t])
                          for b in non_slack_buses, t in 1:instance.time]
        overflow = [value(vars.overflow[lm.name, t])
                    for lm in instance.lines, t in 1:instance.time]
        violations = UnitCommitment.find_violations(instance=instance,
                                                    net_injections=net_injections,
                                                    overflow=overflow,
                                                    isf=model.isf,
                                                    lodf=model.lodf)
    end
    @info @sprintf("Verified transmission limits in %.2f seconds", time_screening)
    return violations
end


function enforce_transmission(model::UnitCommitmentModel, violations::Array{Violation, 1})
    for v in violations
        enforce_transmission(model=model,
                             violation=v,
                             isf=model.isf,
                             lodf=model.lodf)
    end
end


export UnitCommitmentModel, build_model, get_solution, optimize!
