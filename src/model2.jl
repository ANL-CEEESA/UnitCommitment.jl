# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.
# Writen by Alinson S. Xavier <axavier@anl.gov>

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


"""
Create a JuMP model using the variables and constraints defined by
the collection of `UCComponent`s in `formulation`.

Parameters
===
  * `isf`: injection shift factors
  * `lodf`: line outage distribution factors
"""
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
                     formulation::Vector{UCComponent} = UnitCommitment.DefaultFormulation,
                    ) :: UnitCommitmentModel2

    if (filename == nothing) && (instance == nothing)
        error("Either filename or instance must be specified")
    end
    
    if filename != nothing
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
        if isf == nothing
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
        if model == nothing
            if optimizer == nothing
                mip = Model()
            else
                mip = Model(optimizer)
            end
        else
            mip = model
        end
    @info "About to build model"
        model = UnitCommitmentModel2(mip,         # JuMP.Model
                                     DotDict(),   # vars
                                     DotDict(),   # eqs
                                     DotDict(),   # exprs
                                     instance,    # UnitCommitmentInstance
                                     isf,         # injection shift factors
                                     lodf,        # line outage distribution factors
                                     AffExpr(),   # obj
                                     formulation, # formulation
                                    )

        # Prepare variables
        for var in get_required_variables(formulation)
          add_variable(mip, model, instance, UnitCommitment.var_list[var])
        end # prepare variables

        # Prepare constraints
        for constr in get_required_constraints(formulation)
          add_constraint(mip, model, instance, constr)
        end # prepare constraints

        # Prepare expressions (in this case, affine expressions that are later used as part of constraints or objective)
        #   * :startup_cost => contribution to objective of startup costs
        for field in [:startup_cost] #[:net_injection]
            setproperty!(model.exprs, field, OrderedDict())
        end

        # Add components to mip
        for c in formulation
          c.add_component(c, mip, model)
        end

        # Add objective function
        build_obj_function!(model)
    end # end timing of building model
    @info @sprintf("Built model in %.2f seconds", time_model)

    if variable_names
        set_variable_names!(model)
    end
    
    return model
end # build_model


"""
Add a particular variable to `model.vars`.
"""
function add_variable(mip::JuMP.Model,
                      model::UnitCommitmentModel2,
                      instance::UnitCommitmentInstance,
                      var::UCVariable)
  setproperty!(model.vars, var.name, OrderedDict())
  x = getproperty(model.vars, var.name)
  if !isnothing(var.add_variable)
    var.add_variable(var, x, mip, instance)
    return
  end

  # The following is a bit complex-looking, but the idea is ultimately straightforward
  # We want to loop over the possible index values for var,
  # for every dimension of var (e.g., looping over units and time)
  # The OrderedDict `ind_to_field` maps a UCElement to the corresponding field name within a UnitCommitmentInstance
  # NB: this can be an array of field names, such as [:x, :y], which means we want to access instance.x.y
  # Furthermore, `var` has an array `indices` of UCElement values, describing which index loops over
  # So all we want is to extract the _length_ of the corresponding field of `instance`
  # We create a Tuple so we can feed it to CartesianIndices
  fields = UnitCommitment.ind_to_field(var.indices)
  num_indices = UnitCommitment.num_indices(fields)

  # There is some really complicated logic below that one day needs to be improved
  # (we need to handle nested indices, and this is one way that hopefully works, but it is definitely not intuitive)
  loop_primitive = UnitCommitment.loop_over_indices(UnitCommitment.get_indices_tuple(instance, fields))
  indices = UnitCommitment.get_indices(loop_primitive) # returns an array of tuples? or a unit range maybe.

  for ind in indices
    # For each of the indices, check if the field corresponding to that index has a name
    # Then we will index the variable by that name instead of the integer
    curr_tuple = Tuple(ind)
    new_tuple = ()
    for i in 1:num_indices
      curr_field = UnitCommitment.get_nested_field(instance, fields, i, curr_tuple)
      if :name in propertynames(curr_field)
        new_tuple = (new_tuple..., curr_field.name)
      else
        new_tuple = (new_tuple..., curr_tuple[i])
      end
    end
    name = string(var.name, "[")
    for (i,val) in enumerate(new_tuple)
      name = string(name, val, i < num_indices ? "," : "")
    end
    name = string(name, "]")
    if num_indices == 1
      new_tuple = new_tuple[1]
    end
    x[new_tuple] = @variable(mip, 
                             lower_bound=var.lb,
                             upper_bound=var.ub,
                             integer=var.integer,
                             base_name=name)
  end
  ### DEBUG
  #if var.name == :reserve_shortfall
  #  @show var.name, num_indices, loop_primitive, indices, x
  #  #@show JuMP.all_variables(mip)
  #end
  ### DEBUG
end # add_variable


"""
Add constraint to `model.eqs` (set of affine expressions represent left-hand side of constraints).
"""
function add_constraint(mip::JuMP.Model,
                        model::UnitCommitmentModel2,
                        instance::UnitCommitmentInstance,
                        constr::Symbol)
  setproperty!(model.eqs, constr, OrderedDict())
end # add_constraint


"""
Components of the objective include, summed over time:
  * production cost above minimum
  * minimum production cost if generator is on
  * startup cost
  * shutdown cost
  * cost of not meeting shortfall
  * penalty for not meeting or exceeding load (using curtai variable)
  * shutdown cost
"""
function build_obj_function!(model::UnitCommitmentModel2)
    @objective(model.mip, Min, model.obj)
end # build_obj_function


function enforce_transmission(;
                              model::UnitCommitmentModel2,
                              violation::Violation,
                              isf::Array{Float64,2},
                              lodf::Array{Float64,2})::Nothing
    
    instance, mip, vars = model.instance, model.mip, model.vars
    limit::Float64 = 0.0
        
    if violation.outage_line == nothing
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
    
    # |flow| <= limit + overflow
    overflow = vars.overflow[violation.monitored_line.name, violation.time]
    @constraint(mip,  flow <= limit + overflow)
    @constraint(mip, -flow <= limit + overflow)
    
    if violation.outage_line == nothing
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
end # enforce_transmission


function set_variable_names!(model::UnitCommitmentModel2)
    @info "Setting variable and constraint names..."
    time_varnames = @elapsed begin
        #set_jump_names!(model.vars) # amk: already set
        set_jump_names!(model.eqs)
    end
    @info @sprintf("Set names in %.2f seconds", time_varnames)
end # set_variable_names


function set_jump_names!(dict)
    for name in keys(dict)
        for idx in keys(dict[name])
            idx_str = isa(idx, Tuple) ? join(map(string, idx), ",") : idx
            set_name(dict[name][idx], "$name[$idx_str]")
        end
    end
end # set_jump_names


function get_solution(model::UnitCommitmentModel2)
    instance, T = model.instance, model.instance.time
    function timeseries(vars, collection)
        return OrderedDict(b.name => [round(value(vars[b.name, t]), digits=5) for t in 1:T]
                           for b in collection)
    end
    function production_cost(g)
        return [value(model.vars.is_on[g.name, t]) * g.min_power_cost[t] +
                sum(Float64[value(model.vars.segprod[g.name, k, t]) * g.cost_segments[k].cost[t]
                            for k in 1:length(g.cost_segments)])
                for t in 1:T]
    end
    function production(g)
        return [value(model.vars.is_on[g.name, t]) * g.min_power[t] +
                sum(Float64[value(model.vars.segprod[g.name, k, t])
                            for k in 1:length(g.cost_segments)])
                for t in 1:T]
    end
    function startup_cost(g)
        #S = length(g.startup_categories)
        #return [sum(g.startup_categories[s].cost * value(model.vars.startup[g.name, s, t])
        #            for s in 1:S)
        #        for t in 1:T]
        return [ value.(model.exprs.startup_cost[g.name, t]) for t in 1:T ]
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
end # get_solution


function fix!(model::UnitCommitmentModel2, solution)::Nothing
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
end # fix!


function set_warm_start!(model::UnitCommitmentModel2, solution)::Nothing
    vars, instance, T = model.vars, model.instance, model.instance.time
    for g in instance.units
        for t in 1:T
            JuMP.set_start_value(vars.is_on[g.name, t], solution["Is on"][g.name][t])
            JuMP.set_start_value(vars.switch_on[g.name, t], solution["Switch on"][g.name][t])
            JuMP.set_start_value(vars.switch_off[g.name, t], solution["Switch off"][g.name][t])
        end
    end
end # set_warm_start


function optimize!(model::UnitCommitmentModel2;
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
end # optimize!


"""
Identify which transmission lines are violated.
See find_violations description from screening.jl.
"""
function find_violations(model::UnitCommitmentModel2)
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
end # find_violations


function enforce_transmission(model::UnitCommitmentModel2, violations::Array{Violation, 1})
    for v in violations
        enforce_transmission(model=model,
                             violation=v,
                             isf=model.isf,
                             lodf=model.lodf)
    end
end # enforce_transmission


export UnitCommitmentModel2, build_model, get_solution, optimize!
