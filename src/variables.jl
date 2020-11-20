using DataStructures # for OrderedDict
using JuMP

##################################################
# Variables
#mutable struct UCVariable
#  "Name of the variable."
#  name::Symbol
#  "What does the variable represent?"
#  description::String
#  "Global lower bound for the variable (may be adjusted later)."
#  lb::Float64
#  "Global upper bound for the variable (may be adjusted later)."
#  ub::Float64
#  "Is the variable integer-restricted?"
#  integer::Bool
#  "What are we indexing over?"*
#  " Recursive structure, e.g., [X,Y] means Y is a field in X,"*
#  " and [X,[Y1,Z],Y2] means Y1 and Y2 are fields in X and Z is a field in Y1.\n"*
#  " [ X, [Y,A,B], [Y,A,A], [Z,[D,E],F], T ]\n"*
#  " => [x, y1, y1.a, y1.b, y2, y2.a1, y2.a2, z, z.d, z.d.e, z.f, t]."
#  indices::Vector
#  "Function to add the variable; if this is missing, we will attempt to add the variable automatically using the `indices`. Signature should be (variable, model.vars.familyname, mip, instance)."
#  add_variable::Union{Function,Nothing}
#end # UCVariable

# TODO Above did not work for some reason
mutable struct UCVariable
  name::Symbol
  description::String
  lb::Float64
  ub::Float64
  integer::Bool
  indices::Vector
  add_variable::Union{Function,Nothing}
end

"""
It holds that x(t,t') = 0 if t' does not belong to 𝒢 = [t+DT, t+TC-1].
This is because DT is the minimum downtime, so there is no way x(t,t')=1 for t'<t+DT
and TC is the "time until cold" => if the generator starts afterwards, always has max cost.
"""
function add_downtime_arcs(var::UCVariable,
                           x::OrderedDict,
                           mip::JuMP.Model,
                           instance::UnitCommitmentInstance)
  T = instance.time
  for g in instance.units
    S = length(g.startup_categories)
    if S == 0
      continue
    end

    DT = g.min_downtime # minimum time offline
    TC = g.startup_categories[S].delay # time offline until totally cold

    for t1 = 1:T-1
      for t2 = t1+1:T
        # It holds that x(t,t') = 0 if t' does not belong to 𝒢 = [t+DT, t+TC-1]
        # This is because DT is the minimum downtime, so there is no way x(t,t')=1 for t'<t+DT
        # and TC is the "time until cold" => if the generator starts afterwards, always has max cost
        if (t2 < t1 + DT) || (t2 >= t1 + TC)
          continue
        end

        name = string(var.name, "[", g.name, ",", t1, ",", t2, "]")
        x[g.name, t1, t2] = @variable(mip,
                                      lower_bound=var.lb,
                                      upper_bound=var.ub,
                                      integer=var.integer,
                                      base_name=name)
      end # loop over time 2
    end # loop over time 1
  end # loop over units
end # add_downtime_arcs


"""
If there is a penalty specified for not meeting the reserve, then we add a reserve shortfall variable.
"""
function add_reserve_shortfall(var::UCVariable,
                               x::OrderedDict,
                               mip::JuMP.Model,
                               instance::UnitCommitmentInstance)
  T = instance.time
  for t = 1:T
    if instance.shortfall_penalty[t] > 1e-7
      name = string(var.name, "[", t, "]")
      x[t] = @variable(mip,
                       lower_bound=var.lb,
                       upper_bound=var.ub,
                       integer=var.integer,
                       base_name=name)
    end
  end # loop over time
end # add_reserve_shortfall


"""
Variables that the model may (or may not) use.

Note the relationship
  r_g(t) = bar{p}_g(t) - p_g(t)
         = bar{p}'_g(t) - p'_g(t)
"""
var_list = OrderedDict{Symbol,UCVariable}(
  :prod
    => UCVariable(:prod,
                  "[gen, t]; power from generator gen at time t; p_g(t) = p'_g(t) + g.min_power[t] * u_g(t)",
                  0., Inf, false,
                  [Unit, Time], nothing),
  :prod_above
    => UCVariable(:prod_above,
                  "[gen, t]; production above minimum required level; p'_g(t)",
                  0., Inf, false,
                  [Unit, Time], nothing ),
  :max_power_avail
    => UCVariable(:max_power_avail,
                  "[gen, t]; maximum power available from generator gen at time t; bar{p}_g(t) = p_g(t) + r_g(t)",
                  0., Inf, false,
                  [Unit, Time], nothing),
  :max_power_avail_above
    => UCVariable(:max_power_avail_above,
                  "[gen, t]; maximum power available above minimum from generator gen at time t; bar{p}'_g(t)",
                  0., Inf, false,
                  [Unit, Time], nothing),
  :segprod
    => UCVariable(:segprod,
                  "[gen, seg, t]; how much generator gen produces on segment seg in time t; p_g^l(t)",
                  0., Inf, false,
                  [ [Unit, CostSegment], Time], nothing),
  :reserve
    => UCVariable(:reserve,
                  "[gen, t]; reserves provided by gen at t; r_g(t)",
                  0., Inf, false,
                  [Unit, Time], nothing),
  :reserve_shortfall
    => UCVariable(:reserve_shortfall,
                  "[t]; reserve shortfall at gen at t; s_R(t)",
                  0., Inf, false,
                  [Time], add_reserve_shortfall),
  :is_on
    => UCVariable(:is_on,
                  "[gen, t]; is gen on at t; u_g(t)",
                  0., 1., true,
                  [Unit, Time], nothing),
  :switch_on
    => UCVariable(:switch_on,
                  "[gen, t]; indicator that gen will be turned on at t; v_g(t)",
                  0., 1., true,
                  [Unit, Time], nothing),
  :switch_off
    => UCVariable(:switch_off,
                  "[gen, t]; indicator that gen will be turned off at t; w_g(t)",
                  0., 1., true,
                  [Unit, Time], nothing),
  :net_injection
    => UCVariable(:net_injection,
                  "[bus.name, t]",
                  -1e100, Inf, false,
                  [Bus, Time], nothing),
  :curtail
    => UCVariable(:curtail,
                  "[bus.name, t]; upper bound is max load at the bus at time t",
                  0., Inf, false,
                  [Bus, Time], nothing),
  :flow
    => UCVariable(:flow,
                  "[violation.monitored_line.name, t]",
                  -1e100, Inf, false,
                  [Violation, Time], nothing),
  :overflow
    => UCVariable(:overflow, 
                  "[transmission_line.name, t]; how much flow above the transmission limits (in MW) is allowed",
                  0., Inf, false,
                  [TransmissionLine, Time], nothing),
  :loads
    => UCVariable(:loads,
                  "[price_sensitive_load.name, t]; production to meet demand at a set price, if it is economically sensible, independent of the rest of the demand; upper bound is demand at this price at time t",
                  0., Inf, false,
                  [PriceSensitiveLoad, Time], nothing),
  :startup
    => UCVariable(:startup,
                  "[gen, startup_category, t]; indicator that generator g starts up in startup_category at time t; 𝛿_g^s(t)",
                  0., 1., true,
                  [ [Unit, StartupCategory], Time], nothing),
  :downtime_arc
    => UCVariable(:downtime_arc,
                  "[gen, t, t']; indicator for shutdown at t and starting at t'",
                  0., 1., true,
                  [Unit, Time, Time], add_downtime_arcs),
) # var_list

#var_symbol_list =
#  [
#   :prod_above,     # [gen, t], ≥ 0
#   :segprod,        # [gen, t, segment], ≥ 0
#   :reserve,        # [gen, t], ≥ 0
#   :is_on,          # [gen, t], binary
#   :switch_on,      # [gen, t], binary
#   :switch_off,     # [gen, t], binary
#   :net_injection,  # [bus.name, t], urs?
#   :curtail,        # [bus.name, t], domain [0, b.load[t]]
#   :overflow,       # [transmission_line.name, t], ≥ 0
#   :loads,          # [price_sensitive_load.name, t], domain [0, ps.demand[t]]
#   :startup         # [gen, t, startup_category], binary
#  ]


"""
For a particular UCElement, which is the field in UnitCommitmentInstance that this corresponds to?
This is used to determine indexing and ranges, e.g., `is_on` is indexed over Unit and Time,
so the variable `is_on` will range in the first index from 1 to length(instance.units)
and on the second index from 1 to instance.time.
"""
ind_to_field_dict = OrderedDict{Type{<:UCElement},Symbol}(
  Time                => :time,
  Bus                 => :buses,
  Unit                => :units,
  TransmissionLine    => :lines,
  PriceSensitiveLoad  => :price_sensitive_loads,
  CostSegment         => :cost_segments,
  StartupCategory     => :startup_categories,
) # ind_to_field_dict

"""
Take indices and convert them to fields of UnitCommitmentInstance.
"""
function ind_to_field(index::Union{Vector,Type{<:UCElement}}) :: Union{Vector,Symbol}
  if isa(index, Type{<:UCElement})
    return ind_to_field_dict[index]
  else
    return [ ind_to_field(t) for t in index ]
  end
end # ind_to_field

function num_indices(v) :: Int64
  if !isa(v, Array)
    return 1
  else
    return sum(num_indices(v[i]) for i in 1:length(v))
  end
end # num_indices


"""
Can return
  * UnitRange -> iterate over this range
  * Array{UnitRange} -> cross product of the ranges in the array
  * Tuple(UnitRange, Array{UnitRange}) -> the array length should be the same as the range of the UnitRange
"""
function get_indices_tuple(obj::Any, fields::Union{Symbol,Vector,Nothing} = nothing)
  if isa(fields, Symbol)
    return get_indices_tuple(getfield(obj,fields))
  end
  if fields == nothing || (isa(fields,Array) && length(fields) == 0)
    if isa(obj, Array)
      return UnitRange(1,length(obj))
    elseif isa(obj, Int)
      return UnitRange(1,obj)
    else
      return UnitRange{Int64}(0:-1)
      #return UnitRange(1,1)
    end
  end

  if isa(obj,Array)
    indices = (
               UnitRange(1,length(obj)),
               ([
                 isa(f,Array) ? get_indices_tuple(getfield(x, f[1]), f[2:end]) : get_indices_tuple(getfield(x, f))
                 for x in obj
                ] for f in fields)...
              )
    #         more_indices = ([
    #                 isa(f,Array) ? get_indices_tuple(getfield(x, f[1]), f[2:end]) : get_indices_tuple(getfield(x, f))
    #                 for x in obj
    #               ] for f in fields
    #             )
    #         indices = (UnitRange(1,length(obj)),more_indices...)
  else
    indices = ()
    for f in fields
      if isa(f,Array)
        indices = (indices..., get_indices_tuple(getfield(obj, f[1]), f[2:end]))
      else
        indices = (indices..., get_indices_tuple(obj,f))
      end
    end
    #         indices = (
    #             isa(f,Array) ? get_indices_tuple(getfield(obj, f[1]), f[2:end]) : get_indices_tuple(getfield(obj, f))
    #                 for f in fields
    #             )
    #         (
    #             isa(f,Array) ? get_indices_tuple(getfield(obj, f[1]), f[2:end]) : get_indices_tuple(getfield(obj, f))
    #             for f in fields
    #         )
    #         indices = (indices...,)
  end # check if obj is Array or not
    
  return indices
end # get_indices_tuple

function loop_over_indices(indices::Any)
  loop = nothing
  should_print = false

  if isa(indices, UnitRange)
    loop = indices
  elseif isa(indices, Array{UnitRange{Int64}}) || isa(indices, Tuple{Int, UnitRange})
    loop = Base.product(Tuple(indices)...)
  elseif isa(indices, Tuple{UnitRange, Array})
    loop = ()
    for t in zip(indices...)
      loop = (loop..., loop_over_indices(t)...)
    end
  elseif isa(indices,Tuple)
    loop = ()
    for i in indices
      loop = (loop..., loop_over_indices(i))
    end
    loop = Base.product(loop...)
  else
    error("Why are we here?")
    #loop = Base.product(loop_over_indices(indices)...)
  end

  if should_print
    for i in loop
      @show i
    end
  end
  return loop
end # loop_over_indices


function expand_tuple(x::Tuple)
  y = ()
  for i in x
    if isa(i, Tuple)
      y = (y..., expand_tuple(i)...)
    else
      y = (y..., i)
    end
  end
  return y
end # expand_tuple


function expand_tuple(X::Array{<:Tuple})
  return [ expand_tuple(x) for x in X ]
end # expand_tuple


function get_indices(x::Array)
  return expand_tuple(x)
end
function get_indices(x::Base.Iterators.ProductIterator)
  return get_indices(collect(x))
end


"""
Access `t.f`, special terminal case of `get_nested_field`.
"""
function get_nested_field(t::Any, f::Symbol)
  return getfield(t,f)
end # get_nested_field


"""
Access `t.f`, where `f` could be a subfield.
"""
function get_nested_field(t::Any, f::Vector{Symbol})
  if length(f) > 1
    return get_nested_field(getfield(t,f[1]), f[2:end])
  else
    return getfield(t,f[1])
  end
end # get_nested_field


"""
Given a set of indices of UCVariable, e.g., [[X,Y],T],
and a UnitCommitmentInstance instance,
if we want to access the field corresponding to Y,
then we call get_nested_field(instance, [[X,Y],T], 2, (4,3)),
which will return instance.X[4].Y[3] if Y is a vector,
and just instance.X[4].Y otherwise.

===
Termination Conditions

If `i` <= 0, then we only care about instance, and not the field.
If `field` is a Symbol and `i` >= 1, then we want to explore instance.field (index t[i] or t).
Note that if `i` >= 1, then `field` must be a symbol.
If `i` == 1, then `t` can be an Int.

===
Parameters
  * instance::Any --> all fields will be from instance, or nested fields of fields of instance.
  * field::Union{Vector,Symbol,Nothing} --> either the field we want to access, or a vector of fields, and we will want field[i].
  * i::Int --> which field to access.
  * t::Tuple --> how to go through the fields of instance to get the right field, length needs to be at least `i`.
"""
function get_nested_field(instance::Any, field::Union{Vector,Symbol,Nothing}, i::Int, t::Union{Tuple, Int})
  # Check data
  if isa(field, Vector)
    if i >= 2 && (!isa(t,Tuple) || length(t) < i)
      error("Tuple of indices to get nested field needs to be at least the length of the index we want to get.")
    end
  end

  if isa(field, Symbol) || i <= 0
    # i = 0 can happen in the recursive call
    # What it means is that we do not want a field of the instance, but the instance itself
    # TODO handle other iterable types and empty arrays
    f = (isa(field, Symbol) && i >= 1) ? getfield(instance, field) : instance
    if isa(f,Vector)
      if length(f) == 0
        error("Trying to iterate over empty field!")
      else
        return isa(t,Int) ? f[t] : f[t[i]]
      end
    else
      return f
    end
  end # check termination conditions (f is field or i <= 0)

  # Loop over the fields until we find where index i is located
  # It may be nested inside an array, so that is why we recurse
  start_ind = 0
  for f in field
    curr_len = isa(f, Vector) ? length(f) : 1
    if start_ind + curr_len >= i
      if isa(f, Vector)
        new_field_is_iterable = isa(getfield(instance, f[1]), Vector) 
        if new_field_is_iterable
          return get_nested_field(getfield(instance, f[1])[t[start_ind+1]], f[2:end], i - start_ind - 1, isa(t,Tuple) ? t[start_ind+2:end] : t)
        else
          return get_nested_field(getfield(instance, f[1]), f[2:end], i - start_ind - 1, isa(t,Tuple) ? t[start_ind+2:end] : t)
        end
      else 
        # f is hopefully a symbol...
        return get_nested_field(instance, f, 1, isa(t,Tuple) ? t[start_ind+1] : t)
      end
    end
    start_ind += curr_len
  end

  return nothing
end # get_nested_field


#"""
#Get ranges for the indices of a UCVariable along dimension `i`,
#making sure that the right fields ranges are calculated via `get_nested_field` and `ind_to_field`.
#"""
#function get_range(arr::UCVariable, instance::UnitCommitmentInstance, i::Int) :: UnitRange
#  arr = ind_to_field[var.indices[i]]
#  f = get_nested_field(instance, arr)
#  if isa(f, Array)
#    return 1:length(f)
#  elseif isa(f, Int)
#    return 1:f
#  else
#    error("Unknown type to generate UnitRange from: ", typeof(f))
#  end
#end # get_range

export UCVariable
