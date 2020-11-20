# Determine which formulation is being used

using DataStructures # for OrderedDict
using JuMP

RESERVES_WHEN_START_UP = true
RESERVES_WHEN_RAMP_UP = true
RESERVES_WHEN_RAMP_DOWN = true
RESERVES_WHEN_SHUT_DOWN = true

mutable struct UnitCommitmentModel2
    mip::JuMP.Model
    vars::DotDict
    eqs::DotDict
    exprs::DotDict
    instance::UnitCommitmentInstance
    isf::Array{Float64, 2}
    lodf::Array{Float64, 2}
    obj::AffExpr
    components::Array{UCComponent,1}
end # UnitCommitmentModel2


##################################################
## Required constraints

function add_required_constraints_default(c::UCComponent,
                                          mip::JuMP.Model,
                                          model::UnitCommitmentModel2)
  T = model.instance.time
  for g in model.instance.units
    gi = g.name
    if !all(g.must_run) && any(g.must_run)
      error("Partially must-run units are not currently supported.")
    end

    known_initial_conditions = (g.initial_status != nothing && g.initial_power != nothing)
    if known_initial_conditions
      if g.initial_status > 0 && g.initial_power > 0
        # Generator was on (for g.initial_status time periods),
        # so cannot be more switched on until the period after the first time it can be turned off
        fix(model.vars.switch_on[gi, 1], 0.0; force = true)

        # amk added below
        # (redundant to min_uptime[gi, 0] constraint)
        # Unit will continue to be on for min_uptime - g.initial_status periods
        UT = max(g.min_uptime - g.initial_status, 0)
        for t = 1:min(UT, T)
          fix(model.vars.switch_off[gi, t], 0.0; force = true)
          fix(model.vars.is_on[gi, t], 1.0; force = true)
          if t < T
            # If on in t, then cannot be turned on in t+1
            fix(model.vars.switch_on[gi, t+1], 0.0; force = true)
          end
        end
      end

      if g.initial_status < 0
        # Generator is initially off (for -g.initial_status time periods)
        # Cannot be switched off more
        fix(model.vars.switch_off[gi, 1], 0.0; force = true)

        # amk added below, but probably redundant due to min_downtime[gi, 0] constraint
        DT = max(g.min_downtime + g.initial_status, 0)
        for t = 1:min(DT, T)
          fix(model.vars.switch_on[gi, t], 0.0; force = true)
          fix(model.vars.is_on[gi, t], 0.0; force = true)
          if t < T
            # If off in t, then cannot be turned off in t+1
            fix(model.vars.switch_off[gi, t+1], 0.0; force = true)
          end
        end
      end

      if g.initial_power > g.shutdown_limit
        # Generator producing too much to be turned off in the first time period
        # TODO check what happens with these variables when exporting the model
        # (can a binary variable have bounds x = 0?)
        #eqs.shutdown_limit[gi, 0] = @constraint(mip, vars.switch_off[gi, 1] <= 0)
        fix(model.vars.switch_off[gi, 1], 0.; force = true)
      end
    end # known_initial_conditions

    for t = 1:T
      if !g.provides_spinning_reserves[t]
        fix(model.vars.reserve[gi, t], 0.0; force = true)
      end

      if g.must_run[t]
        # If the generator _must_ run, then it is obviously on and cannot be switched off
        fix(model.vars.is_on[gi, t], 1.0; force = true)
        fix(model.vars.switch_off[gi, t], 0.0; force = true)
        if t == 1 && known_initial_conditions && g.initial_status < 0
          # In the first time period, force to switch on if was off before
          fix(model.vars.switch_on[gi, t], 1.0; force = true)
        else
          # Otherwise, it is on, and will never turn off, so will never need to turn on
          fix(model.vars.switch_on[gi, t], 0.0; force = true)
        end
      end # g.must_run[t]
    end # loop over time
  end # loop over units

  for t = 1:T
    for lm in model.instance.lines
      add_to_expression!(model.obj, model.vars.overflow[lm.name, t], lm.flow_limit_penalty[t])
    end # loop over lines
  end # loop over time
end # add_required_constraints_default

DefaultRequiredConstraints = UCComponent(
  "DefaultRequiredConstraints",
  "Fix variables if a certain generator _must_ run or if a generator provides spinning reserves."*
  " Also, add overflow penalty to objective for each transmission line.",
  RequiredConstraints,
  [:is_on, :switch_on, :switch_off, :reserve, :overflow],
  nothing,
  add_required_constraints_default,
  nothing
) # DefaultRequiredConstraints


##################################################
## System constraints

function add_system_constraints_default(c::UCComponent,
                                        mip::JuMP.Model,
                                        model::UnitCommitmentModel2)
  #nop
end # add_system_constraints_default

DefaultSystemConstraints = UCComponent(
  "DefaultSystemConstraints",
  "Ensure constraints on system, across units / buses, are met.",
  SystemConstraints,
  nothing,
  nothing,
  add_system_constraints_default,
  nothing
) # DefaultSystemConstraints


##################################################
## Generation limits

function add_generation_limits_default(c::UCComponent,
                                       mip::JuMP.Model,
                                       model::UnitCommitmentModel2)
  vars, eqs = model.vars, model.eqs
  T = model.instance.time
  for t = 1:T
    for g in model.instance.units
      gi = g.name

      # Objective function terms for production costs
      # Part of (69) of Kneuven et al. (2020) as C^R_g * u_g(t) term
      add_to_expression!(model.obj, vars.is_on[gi, t], g.min_power_cost[t])

      # Production limit
      # Equation (18) in Kneuven et al. (2020)
      #   as \bar{p}_g(t) \le \bar{P}_g u_g(t)
      # amk: this is a weaker version of (20) and (21) in Kneuven et al. (2020)
      #      but keeping it here in case those are not present
      power_diff = max(g.max_power[t], 0.) - max(g.min_power[t], 0.)
      if power_diff < 1e-7
        power_diff = 0.
      end
      eqs.prod_limit[gi, t] =
        @constraint(mip,
                    vars.prod_above[gi, t] + vars.reserve[gi, t]
                    <= power_diff * vars.is_on[gi, t])
    end # loop over units
  end # loop over time
end # add_generation_limits_default

# Default
DefaultGenerationLimits = UCComponent(
  "DefaultSystemConstraints",
  "Ensure constraints on system are met."*
  " Based on Garver (1962) and Morales-España et al. (2013)."*
  " Eqns. (18), part of (69) in Kneuven et al. (2020).",
  GenerationLimits,
  [:is_on, :prod_above, :reserve],
  [:prod_limit],
  add_generation_limits_default,
  nothing
) # DefaultGenerationLimits


##################################################
## Piecewise production

function add_piecewise_production_Garver62(c::UCComponent,
                                           mip::JuMP.Model,
                                           model::UnitCommitmentModel2)
  vars, eqs = model.vars, model.eqs
  T = model.instance.time
  for t = 1:T
    for g in model.instance.units
      gi = g.name
      K = length(g.cost_segments)
      for k in 1:K
        # Equation (42) in Kneuven et al. (2020)
        # Without this, solvers will add a lot of implied bound cuts to have this same effect
        # NB: when reading instance, UnitCommitment.jl already calculates difference between max power for segments k and k-1
        #     so the value of cost_segments[k].mw[t] is the max production *for that segment*
        eqs.segprod_limit[gi, k, t] =
          @constraint(mip,
                      vars.segprod[gi, k, t]
                      <= g.cost_segments[k].mw[t] * vars.is_on[gi, t])

        # Also add this as an explicit upper bound on segprod to make the solver's work a bit easier
        set_upper_bound(vars.segprod[gi, k, t], g.cost_segments[k].mw[t])

        # Definition of production
        # Equation (43) in Kneuven et al. (2020)
        eqs.prod_above_def[gi, t] =
          @constraint(mip,
                      vars.prod_above[gi, t]
                      == sum(vars.segprod[gi, k, t] for k in 1:K))

        # Objective function
        # Equation (44) in Kneuven et al. (2020)
        add_to_expression!(model.obj, vars.segprod[gi, k, t], g.cost_segments[k].cost[t])
      end # loop over cost segments
    end # loop over units
  end # loop over time
end # add_piecewise_production_Garver62

# Garver, 1962
PiecewiseProduction_Garver62 = UCComponent(
  "PiecewiseProduction_Garver62",
  "Ensure respect of production limits along each segment."*
  " Based on Garver (1962)."*
  " Equations (42), (43), (44) in Kneuven et al. (2020)."*
  " NB: when reading instance, UnitCommitment.jl already calculates difference between max power for segments k and k-1"*
  " so the value of cost_segments[k].mw[t] is the max production *for that segment*.",
  PiecewiseProduction,
  [:segprod, :is_on, :prod_above],
  [:segprod_limit, :prod_above_def],
  add_piecewise_production_Garver62,
  nothing
) # PiecewiseProduction_Garver62


function add_piecewise_production_CarArr06(c::UCComponent,
                                           mip::JuMP.Model,
                                           model::UnitCommitmentModel2)
  vars, eqs = model.vars, model.eqs
  T = model.instance.time
  for t = 1:T
    for g in model.instance.units
      gi = g.name
      K = length(g.cost_segments)
      for k in 1:K
        # Equation (45) in Kneuven et al. (2020)
        # NB: when reading instance, UnitCommitment.jl already calculates difference between max power for segments k and k-1
        #     so the value of cost_segments[k].mw[t] is the max production *for that segment*
        eqs.segprod_limit[gi, k, t] =
          @constraint(mip,
                      vars.segprod[gi, k, t]
                      <= g.cost_segments[k].mw[t])

        # Also add this as an explicit upper bound on segprod to make the solver's work a bit easier
        set_upper_bound(vars.segprod[gi, k, t], g.cost_segments[k].mw[t])

        # Definition of production
        # Equation (43) in Kneuven et al. (2020)
        eqs.prod_above_def[gi, t] =
          @constraint(mip,
                      vars.prod_above[gi, t]
                      == sum(vars.segprod[gi, k, t] for k in 1:K))

        # Objective function
        # Equation (44) in Kneuven et al. (2020)
        add_to_expression!(model.obj, vars.segprod[gi, k, t], g.cost_segments[k].cost[t])
      end # loop over cost segments
    end # loop over units
  end # loop over time
end # add_piecewise_production_CarArr06

# Carrion and Arroyo (2006)
PiecewiseProduction_CarArr06 = UCComponent(
  "PiecewiseProduction_CarArr06",
  "Ensure respect of production limits along each segment."*
  " Based on Garver (1962) and Carrión and Arryo (2006),"*
  " which replaces (42) in Kneuven et al. (2020) with a weaker version missing the on/off variable."*
  " Equations (45), (43), (44) in Kneuven et al. (2020)."*
  " NB: when reading instance, UnitCommitment.jl already calculates difference between max power for segments k and k-1"*
  " so the value of cost_segments[k].mw[t] is the max production *for that segment*.",
  PiecewiseProduction,
  [:segprod, :is_on, :prod_above],
  [:segprod_limit, :prod_above_def],
  add_piecewise_production_CarArr06,
  nothing
) # PiecewiseProduction_CarArr06


function add_piecewise_production_KneOstWat18(c::UCComponent,
                                              mip::JuMP.Model,
                                              model::UnitCommitmentModel2)
  vars, eqs = model.vars, model.eqs
  T = model.instance.time
  for t = 1:T
    for g in model.instance.units
      gi = g.name
      K = length(g.cost_segments)
      for k in 1:K
        # Pbar^{k-1)
        Pbar0 = g.min_power[t] + ( k > 1 ? sum( g.cost_segments[ell].mw[t] for ell in 1:k-1 ) : 0. )
        # Pbar^k
        Pbar1 = g.cost_segments[k].mw[t] + Pbar0

        Cv = 0.
        SU = g.startup_limit   # startup rate
        if Pbar1 <= SU
          Cv = 0.
        elseif Pbar0 < SU # && Pbar1 > SU
          Cv = Pbar1 - SU
        else # Pbar0 >= SU
          Cv = g.cost_segments[k].mw[t] # this will imply that we cannot produce along this segment if switch_on = 1
        end

        Cw = 0.
        SD = g.shutdown_limit  # shutdown rate
        if Pbar1 <= SD
          Cw = 0.
        elseif Pbar0 < SD # && Pbar1 > SD
          Cw = Pbar1 - SD
        else # Pbar0 >= SD
          Cw = g.cost_segments[k].mw[t]
        end


        if g.min_uptime > 1
          # Equation (46) in Kneuven et al. (2020)
          eqs.segprod_limit[gi, k, t] =
            @constraint(mip,
                        vars.segprod[gi, k, t]
                        <= g.cost_segments[k].mw[t] * vars.is_on[gi, t]
                           - Cv * vars.switch_on[gi, t]
                           - (t < T ? Cw * vars.switch_off[gi, t+1] : 0.)
                       )
        else
          # Equation (47a)/(48a) in Kneuven et al. (2020)
          eqs.segprod_limita[gi, k, t] =
            @constraint(mip,
                        vars.segprod[gi, k, t]
                        <= g.cost_segments[k].mw[t] * vars.is_on[gi, t]
                           - Cv * vars.switch_on[gi, t]
                           - (t < T ? max(0, Cv-Cw) * vars.switch_off[gi, t+1] : 0.)
                       )

            # Equation (47b)/(48b) in Kneuven et al. (2020)
          eqs.segprod_limitb[gi, k, t] =
            @constraint(mip,
                        vars.segprod[gi, k, t]
                        <= g.cost_segments[k].mw[t] * vars.is_on[gi, t]
                            - max(0, Cw-Cv) * vars.switch_on[gi, t]
                            - (t < T ? Cw * vars.switch_off[gi, t+1] : 0.)
                       )
        end # check if g.min_uptime > 1

        # Definition of production
        # Equation (43) in Kneuven et al. (2020)
        eqs.prod_above_def[gi, t] =
          @constraint(mip,
                      vars.prod_above[gi, t]
                      == sum(vars.segprod[gi, k, t] for k in 1:K))

        # Objective function
        # Equation (44) in Kneuven et al. (2020)
        add_to_expression!(model.obj, vars.segprod[gi, k, t], g.cost_segments[k].cost[t])

        # Also add an explicit upper bound on segprod to make the solver's work a bit easier
        set_upper_bound(vars.segprod[gi, k, t], g.cost_segments[k].mw[t])
      end # loop over cost segments
    end # loop over units
  end # loop over time
end # add_piecewise_production_KneOstWat18

# Replace (42) with (46) and (48)
PiecewiseProduction_KneOstWat18 = UCComponent(
  "PiecewiseProduction_KneOstWat18",
  "Ensure respect of production limits along each segment."*
  " Based on Kneuven et al. (2018b)."*
  " Eqns. (43), (44), (46), (48) in Kneuven et al. (2020)."*
  " NB: when reading instance, UnitCommitment.jl already calculates difference between max power for segments k and k-1"*
  " so the value of cost_segments[k].mw[t] is the max production *for that segment*.",
  PiecewiseProduction,
  [:segprod, :is_on, :prod_above],
  [:segprod_limit, :segprod_limita, :segprod_limitb, :prod_above_def],
  add_piecewise_production_KneOstWat18,
  nothing
) # PiecewiseProduction_KneOstWat18



##################################################
## Up / down time

function add_updowntime_default(c::UCComponent,
                                mip::JuMP.Model,
                                model::UnitCommitmentModel2)
  vars, eqs = model.vars, model.eqs
  T = model.instance.time
  for t = 1:T
    for g in model.instance.units
      if g.must_run[t]
        continue
      end

      gi = g.name
      known_initial_conditions = (g.initial_status != nothing && g.initial_power != nothing)
      is_initially_on = (known_initial_conditions && (g.initial_status > 0)) ? 1.0 : 0.0

      # Link binary variables
      # Equation (2) in Kneuven et al. (2020), originally from Garver (1962)
      if t == 1
        if known_initial_conditions
          # When initial conditions are unknown, we allow the generator to have is_on = 1 without switch_on = 1
          # This means we do not pay the startup cost in the first time period
          eqs.binary_link[gi, t] =
            @constraint(mip,
                        vars.is_on[gi, t] - is_initially_on ==
                        vars.switch_on[gi, t] - vars.switch_off[gi, t])
        end
      else
        eqs.binary_link[gi, t] =
          @constraint(mip,
                      vars.is_on[gi, t] - vars.is_on[gi, t-1] ==
                      vars.switch_on[gi, t] - vars.switch_off[gi, t])
      end

      # Cannot switch on and off at the same time
      # amk: I am not sure this is in Kneuven et al. (2020)
      eqs.switch_on_off[gi, t] =
        @constraint(mip,
                    vars.switch_on[gi, t] + vars.switch_off[gi, t] <= 1)

      # Minimum up/down-time for initial periods
      # Equations (3a) and (3b) in Kneuven et al. (2020)
      # (using :switch_on and :switch_off instead of :is_on)
      if t == 1 && known_initial_conditions
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

      # Minimum up-time
      # Equation (4) in Kneuven et al. (2020)
      eqs.min_uptime[gi, t] =
        @constraint(mip,
                    sum(vars.switch_on[gi, i]
                        for i in (t - g.min_uptime + 1):t if i >= 1
                       ) <= vars.is_on[gi, t])

      # Minimum down-time
      # Equation (5) in Kneuven et al. (2020)
      eqs.min_downtime[gi, t] =
          @constraint(mip,
                      sum(vars.switch_off[gi, i]
                          for i in (t - g.min_downtime + 1):t if i >= 1
                         ) <= 1 - vars.is_on[gi, t])
    end # loop over units
  end # loop over time
end # add_updowntime_default

# Default
DefaultUpDownTime = UCComponent(
  "DefaultUpDownTime",
  "Ensure constraints on up/down time are met."*
  " Based on Garver (1962), Malkin (2003), and Rajan and Takritti (2005)."*
  " Eqns. (2), (4), (5) in Kneuven et al. (2020).",
  UpDownTime,
  [:is_on, :switch_on, :switch_off, :reserve_shortfall],
  [:binary_link, :min_uptime, :min_downtime, :switch_on_off],
  add_updowntime_default,
  nothing
) # DefaultUpDownTime


##################################################
## Reserves

function add_reserves_default(c::UCComponent,
                              mip::JuMP.Model,
                              model::UnitCommitmentModel2)
  T = model.instance.time
  for t = 1:T
    for g in model.instance.units
      gi = g.name
      if !g.provides_spinning_reserves[t]
        fix(model.vars.reserve[gi, t], 0.0; force=true)
      #else
        #add_to_expression!(mip.exprs.reserve[g.bus.name, t],
        #                   model.vars.reserve[gi, t], 1.0)
      end
    end # loop over units

    # Equation (68) in Kneuven et al. (2020)
    # As in Morales-España et al. (2013a)
    # Akin to the alternative formulation with max_power_avail
    # from Carrión and Arroyo (2006) and Ostrowski et al. (2012)
    shortfall_penalty = model.instance.shortfall_penalty[t]
    model.eqs.min_reserve[t] =
      @constraint(model.mip,
                  sum(model.vars.reserve[g.name, t] for g in model.instance.units)
                  + (shortfall_penalty > 1e-7 ? model.vars.reserve_shortfall[t] : 0.) # amk added
                  >= model.instance.reserves.spinning[t])

    # amk added: Account for shortfall contribution to objective
    if shortfall_penalty > 1e-7
      add_to_expression!(mip.obj,
                         shortfall_penalty,
                         model.vars.reserve_shortfall[t])
    else
      # Not added to the model at all
      #fix(model.vars.reserve_shortfall[t], 0.; force=true)
    end
  end # loop over time
end # add_reserves_default

# Default reserves formulation
DefaultReserves = UCComponent(
  "DefaultReserves",
  "Ensure constraints on reserves are met."*
  " Based on Morales-España et al. (2013a)."*
  " Eqn. (68) from Kneuven et al. (2020).",
  ReserveConstraints,
  [:reserve, :reserve_shortfall],
  [:min_reserve],
  add_reserves_default,
  nothing
) # DefaultReserves


function add_reserves_max_power_avail(c::UCComponent,
                                      mip::JuMP.Model,
                                      model::UnitCommitmentModel2)
  error("add_reserves_max_power_avail is not implemented.")

  T = model.instance.time
  for t = 1:T
    for g in model.instance.units
      gi = g.name
      if !g.provides_spinning_reserves[t]
      end
    end # loop over units

    # Equation (67) in Kneuven et al. (2020)
    # From Carrión and Arroyo (2006) and Ostrowski et al. (2012)
    model.eqs.min_reserve[t] =
      @constraint(model.mip,
                  model.vars.max_power_avail[gi, t]
                  >= sum(bus.load for bus in model.instance.buses) + model.instance.reserves.spinning[t]
                 )
    end # loop over time
end # add_reserves_max_power_avail

# TODO not finished
# Reserves formulation using :max_power_avail
ReservesMaxPowerAvail = UCComponent(
  "ReservesMaxPowerAvail",
  "Ensure constraints on reserves are met."*
  " Based on Carrión and Arroyo (2006) and Ostrowski et al. (2012)."*
  " Eqn. (67) from Kneuven et al. (2020).",
  ReserveConstraints,
  [:max_power_avail, :reserve_shortfall],
  [:min_reserve],
  add_reserves_max_power_avail,
  nothing
) # ReservesMaxPowerAvail


##################################################
## Ramping limits

function add_ramping_ArrCon00(c::UCComponent,
                                 mip::JuMP.Model,
                                 model::UnitCommitmentModel2)
  T = model.instance.time
  vars, eqs = model.vars, model.eqs
  for t = 1:T
    for g in model.instance.units
      gi = g.name
      known_initial_conditions = (g.initial_status != nothing && g.initial_power != nothing)
      is_initially_on = known_initial_conditions && (g.initial_status > 0)
      RU = g.ramp_up_limit
      RD = g.ramp_down_limit
      SU = g.startup_limit
      SD = g.shutdown_limit

      # Ramp up limit
      if t == 1
        # Ignore ramping limits in first period if initial conditions are unknown
        if known_initial_conditions && is_initially_on
          # min power is _not_ multiplied by is_on because if !is_on, then ramp up is irrelevant
          eqs.ramp_up[gi, t] =
            @constraint(mip,
                        g.min_power[t] + vars.prod_above[gi, t]
                        + (RESERVES_WHEN_RAMP_UP ? vars.reserve[gi, t] : 0.)
                        <= g.initial_power + RU)
        end
      else
        max_prod_this_period = g.min_power[t] * vars.is_on[gi, t] + vars.prod_above[gi, t]
        max_prod_this_period += ( RESERVES_WHEN_START_UP || RESERVES_WHEN_RAMP_UP ? vars.reserve[gi, t] : 0. )
        min_prod_last_period = g.min_power[t-1] * vars.is_on[gi, t-1] + vars.prod_above[gi, t-1]

        # Equation (24) in Kneuven et al. (2020)
        eqs.ramp_up[gi, t] =
          @constraint(mip,
                      max_prod_this_period - min_prod_last_period
                      <= RU * vars.is_on[gi, t-1] + SU * vars.switch_on[gi, t])
      end # check if t = 1 or not

      # Ramp down limit
      if t == 1
        # Ignore ramping limits in first period if initial conditions are unknown
        if known_initial_conditions && is_initially_on
          # TODO If RD < SD, or more specifically if
          #        min_power + RD < initial_power < SD
          #      then the generator should be able to shut down at time t = 1,
          #      but the constraint below will force the unit to produce power
          eqs.ramp_down[gi, t] =
            @constraint(mip,
                        g.initial_power
                        - (g.min_power[t] + vars.prod_above[gi, t])
                        <= RD)
        end
      else
        max_prod_last_period = g.min_power[t-1] * vars.is_on[gi, t-1] + vars.prod_above[gi, t-1]
        max_prod_last_period += ( RESERVES_WHEN_SHUT_DOWN || RESERVES_WHEN_RAMP_DOWN ? vars.reserve[gi, t-1] : 0. ) # amk added
        min_prod_this_period = g.min_power[t] * vars.is_on[gi, t] + vars.prod_above[gi, t]

        # Equation (25) in Kneuven et al. (2020)
        eqs.ramp_down[gi, t] =
          @constraint(mip,
                      max_prod_last_period - min_prod_this_period
                      <= RD * vars.is_on[gi, t] + SD * vars.switch_off[gi, t])
      end # check if t = 1 or not
    end # loop over units
  end # loop over time
end # add_ramping_ArrCon00

# Denser version of MorEsp13 ramping
Ramping_ArrCon00 = UCComponent(
  "Ramping_ArrCon00",
  "Ensure constraints on ramping are met."*
  " Based on Arroyo and Conejo (2000)."*
  " Eqns. (24), (25) in Kneuven et al. (2020).",
  RampLimits,
  [:is_on, :prod_above, :reserve],
  [:ramp_up, :ramp_down],
  add_ramping_ArrCon00,
  nothing
) # Ramping_ArrCon00


function add_ramping_MorLatRam13(c::UCComponent,
                                 mip::JuMP.Model,
                                 model::UnitCommitmentModel2)
  T = model.instance.time
  vars, eqs = model.vars, model.eqs
  for t = 1:T
    for g in model.instance.units
      gi = g.name
      known_initial_conditions = (g.initial_status != nothing && g.initial_power != nothing)
      is_initially_on = known_initial_conditions && (g.initial_status > 0)
      time_invariant = (t > 1) ? (abs(g.min_power[t] - g.min_power[t-1]) < 1e-7) : true
      RU = g.ramp_up_limit
      RD = g.ramp_down_limit

      # Ramp up limit
      if t == 1
        # Ignore ramping limits in first period if initial conditions are unknown
        if known_initial_conditions && is_initially_on
          eqs.ramp_up[gi, t] =
            @constraint(mip,
                        g.min_power[t] + vars.prod_above[gi, t]
                        + (RESERVES_WHEN_RAMP_UP ? vars.reserve[gi, t] : 0.)
                        <= g.initial_power + RU)
        end
      else
        # amk: without accounting for time-varying min power terms,
        #      we might get an infeasible schedule, e.g. if min_power[t-1] = 0, min_power[t] = 10
        #      and ramp_up_limit = 5, the constraint (p'(t) + r(t) <= p'(t-1) + RU)
        #      would be satisfied with p'(t) = r(t) = p'(t-1) = 0
        #      Note that if switch_on[t] = 1, then eqns (20) or (21) go into effect
        if !time_invariant
          # Use equation (24) instead
          SU = g.startup_limit
          max_prod_this_period = g.min_power[t] * vars.is_on[gi, t] + vars.prod_above[gi, t]
          max_prod_this_period += ( RESERVES_WHEN_START_UP || RESERVES_WHEN_RAMP_UP ? vars.reserve[gi, t] : 0. )
          min_prod_last_period = g.min_power[t-1] * vars.is_on[gi, t-1] + vars.prod_above[gi, t-1]
          eqs.ramp_up[gi, t] =
            @constraint(mip,
                        max_prod_this_period - min_prod_last_period
                        <= RU * vars.is_on[gi, t-1] + SU * vars.switch_on[gi, t])
        else
          # Equation (26) in Kneuven et al. (2020)
          # TODO what if RU < SU? places too stringent upper bound prod_above[gi, t] when starting up, and creates diff with (24).
          eqs.ramp_up[gi, t] =
            @constraint(mip,
                        vars.prod_above[gi, t]
                        + (RESERVES_WHEN_RAMP_UP ? vars.reserve[gi, t] : 0.)
                        - vars.prod_above[gi, t-1]
                        <= RU)
        end # check time invariant
      end # check if t = 1 or not

      # Ramp down limit
      if t == 1
        if known_initial_conditions && is_initially_on
          # TODO If RD < SD, or more specifically if
          #        min_power + RD < initial_power < SD
          #      then the generator should be able to shut down at time t = 1,
          #      but the constraint below will force the unit to produce power
          eqs.ramp_down[gi, t] =
            @constraint(mip,
                        g.initial_power
                        - (g.min_power[t] + vars.prod_above[gi, t])
                        <= RD)
        end
      else
        # amk: similar to ramp_up, need to account for time-dependent min_power
        if !time_invariant
          # Revert to (25)
          SD = g.shutdown_limit
          max_prod_last_period = g.min_power[t-1] * vars.is_on[gi, t-1] + vars.prod_above[gi, t-1]
          max_prod_last_period += ( RESERVES_WHEN_SHUT_DOWN || RESERVES_WHEN_RAMP_DOWN ? vars.reserve[gi, t-1] : 0. ) # amk added
          min_prod_this_period = g.min_power[t] * vars.is_on[gi, t] + vars.prod_above[gi, t]
          eqs.ramp_down[gi, t] =
            @constraint(mip,
                        max_prod_last_period - min_prod_this_period
                        <= RD * vars.is_on[gi, t] + SD * vars.switch_off[gi, t])
        else
          # Equation (27) in Kneuven et al. (2020)
          # TODO Similar to above, what to do if shutting down in time t and RD < SD? There is a difference with (25).
          eqs.ramp_down[gi, t] =
            @constraint(mip,
                        vars.prod_above[gi, t-1]
                        + (RESERVES_WHEN_RAMP_DOWN ? vars.reserve[gi, t-1] : 0.) # amk added
                        - vars.prod_above[gi, t]
                        <= RD)
        end # check time invariant
      end # check if t = 1 or not
    end # loop over units
  end # loop over time
end # add_ramping_MorLatRam13

# Default
Ramping_MorLatRam13 = UCComponent(
  "Ramping_MorLatRam13",
  "Ensure constraints on ramping are met."*
  " Needs to be used in combination with shutdown rate constraints, e.g., (21b) in Kneuven et al. (2020)."*
  " Based on Morales-España et al. (2013a)."*
  " Eqns. (26)+(27) [replaced by (24)+(25) if time-varying min demand] in Kneuven et al. (2020).",
  RampLimits,
  [:is_on, :prod_above, :reserve],
  [:ramp_up, :ramp_down],
  add_ramping_MorLatRam13,
  nothing
) # Ramping_MorLatRam13


function add_ramping_DamKucRajAta16(c::UCComponent,
                                    mip::JuMP.Model,
                                    model::UnitCommitmentModel2)
  vars, eqs = model.vars, model.eqs
  T = model.instance.time
  for g in model.instance.units
    gi = g.name
    known_initial_conditions = (g.initial_status != nothing && g.initial_power != nothing)
    is_initially_on = known_initial_conditions && (g.initial_status > 0)

    # The following are the same for generator g across all time periods
    SU = g.startup_limit   # startup rate
    SD = g.shutdown_limit  # shutdown rate
    RU = g.ramp_up_limit   # ramp up rate
    RD = g.ramp_down_limit # ramp down rate

    for t = 1:T
      time_invariant = (t > 1) ? (abs(g.min_power[t] - g.min_power[t-1]) < 1e-7) : true
      if t > 1 && !time_invariant
        #warning("Ramping according to Damcı-Kurt et al. (2016) requires time-invariant minimum power. This does not hold for generator ", gi, ".\nmin_power[", t, "] = ", g.min_power[t], "; min_power[", t-1, "] = ", g.min_power[t-1], ". Reverting to equations (24) and (25) based on Arroyo and Conejo (2000).")
      end

      max_prod_this_period = vars.prod_above[gi, t]
      max_prod_this_period += ( RESERVES_WHEN_START_UP || RESERVES_WHEN_RAMP_UP ? vars.reserve[gi, t] : 0. )
      min_prod_last_period = 0.
      if t > 1 && time_invariant
        min_prod_last_period = vars.prod_above[gi, t-1]

        # Equation (35) in Kneuven et al. (2020)
        # Sparser version of (24)
        eqs.str_ramp_up[gi, t] =
          @constraint(mip,
                      max_prod_this_period - min_prod_last_period
                      <= (SU - g.min_power[t] - RU) * vars.switch_on[gi, t] + RU * vars.is_on[gi, t])
      elseif (t == 1 && known_initial_conditions && is_initially_on) || (t > 1 && !time_invariant)
        # (Ignore ramping limits if initial conditions are unknown)
        if t > 1
          min_prod_last_period = vars.prod_above[gi, t-1] + g.min_power[t-1] * vars.is_on[gi, t-1]
        else
          min_prod_last_period = max(g.initial_power, 0.)
        end

        # Add the min prod at time t back in to max_prod_this_period to get _total_ production
        # (instead of using the amount above minimum, as min prod for t < 1 is unknown)
        max_prod_this_period += g.min_power[t] * vars.is_on[gi, t]

        # Modified version of equation (35) in Kneuven et al. (2020)
        # Equivalent to (24)
        eqs.str_ramp_up[gi, t] =
          @constraint(mip,
                      max_prod_this_period - min_prod_last_period
                      <= (SU - RU) * vars.switch_on[gi, t] + RU * vars.is_on[gi, t])
      end

      max_prod_last_period = min_prod_last_period
      max_prod_last_period += ( t > 1 && (RESERVES_WHEN_SHUT_DOWN || RESERVES_WHEN_RAMP_DOWN) ? vars.reserve[gi, t-1] : 0. ) # amk added
      min_prod_this_period = vars.prod_above[gi, t]
      on_last_period = 0.
      if t > 1
        on_last_period = vars.is_on[gi, t-1]
      elseif (known_initial_conditions && g.initial_status > 0)
        on_last_period = 1.
      end

      if t > 1 && time_invariant
        # Equation (36) in Kneuven et al. (2020)
        eqs.str_ramp_down[gi, t] =
          @constraint(mip,
                     max_prod_last_period - min_prod_this_period
                     <= (SD - g.min_power[t] - RD) * vars.switch_off[gi, t] + RD * on_last_period)
      elseif (t == 1 && known_initial_conditions && is_initially_on) || (t > 1 && !time_invariant)
        # (Ignore ramping limits if initial conditions are unknown)
        # Add back in min power
        min_prod_this_period += g.min_power[t] * vars.is_on[gi, t]

        # Modified version of equation (36) in Kneuven et al. (2020)
        # Equivalent to (25)
        eqs.str_ramp_down[gi, t] =
          @constraint(mip,
                     max_prod_last_period - min_prod_this_period
                      <= (SD - RD) * vars.switch_off[gi, t] + RD * on_last_period)
      end
    end # loop over time
  end # loop over units
end # add_ramping_DamKucRajAta16

# Strengthened ramping
Ramping_DamKucRajAta16 = UCComponent(
  "Ramping_DamKucRajAta16",
  "Ensure constraints on ramping are met."*
  " Based on Damcı-Kurt et al. (2016)."*
  " Eqns. (35), (36) in Kneuven et al. (2020).",
  RampLimits,
  [:prod_above, :reserve, :is_on, :switch_on, :switch_off],
  [:str_ramp_up, :str_ramp_down],
  add_ramping_DamKucRajAta16,
  nothing
) # Ramping_DamKucRajAta16


function add_ramping_PanGua16(c::UCComponent,
                              mip::JuMP.Model,
                              model::UnitCommitmentModel2)
  vars, eqs = model.vars, model.eqs
  T = model.instance.time
  for g in model.instance.units
    gi = g.name

    # The following are the same for generator g across all time periods
    UT = g.min_uptime
    SU = g.startup_limit   # startup rate, i.e., max production right after startup
    SD = g.shutdown_limit  # shutdown rate, i.e., max production right before shutdown
    RU = g.ramp_up_limit   # ramp up rate
    RD = g.ramp_down_limit # ramp down rate

    for t = 1:T
      Pbar = g.max_power[t]

      if Pbar < 1e-7
        # Skip this time period if max power = 0
        continue
      end

      #TRD = floor((Pbar - SU) / RD) # ramp down time
      # TODO check amk changed TRD wrt Kneuven et al.
      TRD = ceil((Pbar - SD) / RD)  # ramp down time
      TRU = floor((Pbar - SU) / RU) # ramp up time, can be negative if Pbar < SU

      # TODO check initial time periods: what if generator has been running for x periods?
      # But maybe ok as long as (35) and (36) are also used...
      if UT > 1
        # Equation (38) in Kneuven et al. (2020)
        # Generalization of (20)
        # Necessary that if any of the vars.switch_on = 1 in the sum,
        # then vars.switch_off[gi, t+1] = 0
        eqs.str_prod_limit[gi, t] =
          @constraint(mip,
                      vars.prod_above[gi, t] + g.min_power[t] * vars.is_on[gi, t]
                      + vars.reserve[gi, t]
                      <= Pbar * vars.is_on[gi, t]
                      - (t < T ? (Pbar - SD) * vars.switch_off[gi, t+1] : 0.)
                      - sum((Pbar - (SU + i * RU)) * vars.switch_on[gi, t-i]
                            for i in 0:min(UT-2, TRU, t-1))
                     )

        if UT - 2 < TRU
          # Equation (40) in Kneuven et al. (2020)
          # Covers an additional time period of the ramp-up trajectory, compared to (38)
          eqs.prod_limit_ramp_up_extra_period[gi, t] =
            @constraint(mip,
                        vars.prod_above[gi, t] + g.min_power[t] * vars.is_on[gi, t]
                        + vars.reserve[gi, t]
                        <= Pbar * vars.is_on[gi, t]
                        - sum((Pbar - (SU + i * RU)) * vars.switch_on[gi, t-i]
                              for i in 0:min(UT-1, TRU, t-1))
                       )
        end # check UT - 2 < TRU to cover an additional time period of ramp up

        # Add in shutdown trajectory if KSD >= 0 (else this is dominated by (38))
        KSD = min( TRD, UT-1, T-t-1 )
        if KSD > 0
          KSU = min( TRU, UT-2-KSD, t-1 )
          # Equation (41) in Kneuven et al. (2020)
          eqs.prod_limit_shutdown_trajectory[gi, t] =
            @constraint(mip,
                      vars.prod_above[gi, t] + g.min_power[t] * vars.is_on[gi, t]
                      + (RESERVES_WHEN_SHUT_DOWN ? vars.reserve[gi, t] : 0. ) # amk added
                      <= Pbar * vars.is_on[gi, t]
                      - sum((Pbar - (SD + i * RD)) * vars.switch_off[gi, t+1+i]
                            for i in 0:KSD)
                      - sum((Pbar - (SU + i * RU)) * vars.switch_on[gi, t-i]
                            for i in 0:KSU)
                      - ((KSU >= TRU || KSU > t-2) ? 0. :
                         max( 0, (SU + (KSU + 1) * RU) - (SD + TRD * RD) ) * vars.switch_on[gi, t - (KSU+1)] )
                     )
        end # check KSD > 0
      end # check UT > 1
    end # loop over time
  end # loop over units
end # add_ramping_PanGua16

# Stronger variable upper bounds with ramp limits
Ramping_PanGua16 = UCComponent(
 "Ramping_PanGua16",
 "Add tighter upper bounds on production based on ramp-down trajectory."*
 " Based on (28) in Pan and Guan (2016)."*
 " But there is an extra time period covered using (40) of Kneuven et al. (2020)."*
 " Eqns. (38), (40), (41) in Kneuven et al. (2020).",
 RampLimits,
 [:prod_above, :reserve, :is_on, :switch_on, :switch_off],
 [:str_prod_limit, :prod_limit_ramp_up_extra_period, :prod_limit_shutdown_trajectory],
 add_ramping_PanGua16,
 nothing
) # Ramping_PanGua16


function add_ramping_OstAnjVan12(c::UCComponent,
                                 mip::JuMP.Model,
                                 model::UnitCommitmentModel2)
  vars, eqs = model.vars, model.eqs
  T = model.instance.time
  for g in model.instance.units
    gi = g.name

    # The following are the same for generator g across all time periods
    Pbar = g.max_power[t]

    if Pbar < 1e-7
      # Skip this time period if max power = 0
      continue
    end

    UT = g.min_uptime

    SU = g.startup_limit   # startup rate
    SD = g.shutdown_limit  # shutdown rate
    RU = g.ramp_up_limit   # ramp up rate
    RD = g.ramp_down_limit # ramp down rate

    TRU = floor((Pbar - SU)/RU)
    #TRD = floor((Pbar - SU)/RD)
    # TODO check amk changed TRD wrt Kneuven et al.
    TRD = ceil((Pbar - SD) / RD) # ramp down time

    # TODO check initial conditions, but maybe okay as long as (35) and (36) are also used
    for t = 1:T
      if UT >= 1
        # Equation (37) in Kneuven et al. (2020)
        KSD = min( TRD, UT-1, T-t-1 )
        eqs.str_prod_limit[gi, t] =
          @constraint(mip,
                      vars.prod_above[gi, t] + g.min_power[t] * vars.is_on[gi, t]
                      + (RESERVES_WHEN_RAMP_DOWN ? vars.reserve[gi, t] : 0.) # amk added; TODO: should this be RESERVES_WHEN_RAMP_DOWN or RESERVES_WHEN_SHUT_DOWN?
                      <= Pbar * vars.is_on[gi, t]
                        - sum((Pbar - (SD + i * RD)) * vars.switch_off[gi, t+1+i]
                              for i in 0:KSD)
                      )
      end # check UT >= 1
    end # loop over time
  end # loop over units
end # add_ramping_OstAnjVan12


##################################################
## Startup costs

# TODO: should description go here, or in UCComponent.description? if here, should we eliminate UCComponent.description?
function add_startup_costs_MorLatRam13(c::UCComponent,
                                       mip::JuMP.Model,
                                       model::UnitCommitmentModel2)
  vars, eqs = model.vars, model.eqs
  T = model.instance.time
  for g in model.instance.units
    gi = g.name
    S = length(g.startup_categories)
    if S == 0
      continue
    end

    for t in 1:T
      # If unit is switching on, we must choose a startup category
      # Equation (55) in Kneuven et al. (2020)
      eqs.startup_choose[gi, t] =
        @constraint(mip, vars.switch_on[gi, t] == sum(vars.startup[gi, s, t] for s in 1:S))

        model.exprs.startup_cost[gi, t] = AffExpr()

      for s in 1:S
        # If unit has not switched off in the last `delay` time periods, startup category is forbidden.
        # The last startup category is always allowed.
        if s < S
          range = (t - g.startup_categories[s + 1].delay + 1):(t - g.startup_categories[s].delay)
          # if initial_status < 0, then this is the amount of time the generator has been off
          if g.initial_status != nothing
            initial_sum = (g.initial_status < 0 && (g.initial_status + 1 in range) ? 1.0 : 0.0)
          else
            initial_sum = 0
          end
          # Change of index version of equation (54) in Kneuven et al. (2020):
          #   startup[gi,s,t] ≤ sum_{i=s.delay}^{(s+1).delay-1} switch_off[gi,t-i]
          eqs.startup_restrict[gi, s, t] =
            @constraint(mip, vars.startup[gi, s, t]
                        <= initial_sum + sum(vars.switch_off[gi, i] for i in range if i >= 1))
        end # if s < S (not the last category)

        # Objective function terms for start-up costs
        # Equation (56) in Kneuven et al. (2020)
        add_to_expression!(model.exprs.startup_cost[gi, t],
                           vars.startup[gi, s, t],
                           g.startup_categories[s].cost)
      end # iterate over startup categories
      add_to_expression!(model.obj, model.exprs.startup_cost[gi, t])
    end # iterate over time
  end # iterate over units
end # add_startup_costs_MorLatRam13

# Morales-España, Latorre, and Ramos, 2013
StartupCosts_MorLatRam13 = UCComponent(
  "StartupCosts_MorLatRam13",
  "Extended formulation of startup costs using indicator variables"*
  " based on Muckstadt and Wilson, 1968;"*
  " this version by Morales-España, Latorre, and Ramos, 2013."*
  " Eqns. (54), (55), and (56) in Kneuven et al. (2020)."*
  " Note that the last 'constraint' is actually setting the objective."*
  "\n\tstartup[gi,s,t] ≤ sum_{i=s.delay}^{(s+1).delay-1} switch_off[gi,t-i]"*
  "\n\tswitch_on[gi,t] = sum_{s=1}^{length(startup_categories)} startup[gi,s,t]"*
  "\n\tstartup_cost[gi,t] = sum_{s=1}^{length(startup_categories)} cost_segments[s].cost * startup[gi,s,t]",
  StartupCosts,
  [:startup, :switch_on, :switch_off],
  [:startup_choose, :startup_restrict],
  add_startup_costs_MorLatRam13,
  nothing
) # StartupCosts_MorLatRam13


function add_startup_costs_NowRom00(c::UCComponent,
                                    mip::JuMP.Model,
                                    model::UnitCommitmentModel2)
  error("Not implemented.")
end # add_startup_costs_NowRom00

# Nowak and Römisch, 2000
StartupCosts_NowRom00 = UCComponent(
  "StartupCosts_NowRom00",
  "Introduces auxiliary startup cost variable, c_g^SU(t) for each time period,"*
  " and uses startup status variable, u_g(t);"*
  " there are exponentially many facets in this space,"*
  " but there is a linear-time separation algorithm (Brandenburg et al., 2017).",
  StartupCosts,
  nothing,
  nothing,
  add_startup_costs_NowRom00,
  nothing
) # StartupCosts_NowRom00


function add_startupcosts_KneOstWat20(c::UCComponent,
                                      mip::JuMP.Model,
                                      model::UnitCommitmentModel2)
  vars, eqs = model.vars, model.eqs
  T = model.instance.time

  for g in model.instance.units
    gi = g.name
    S = length(g.startup_categories)
    if S == 0
      continue
    end

    DT = g.min_downtime # minimum time offline
    TC = g.startup_categories[S].delay # time offline until totally cold

    # If initial_status < 0, then this is the amount of time the generator has been off
    initial_time_shutdown = (g.initial_status != nothing && g.initial_status < 0) ? -g.initial_status : 0

    for t in 1:T
      # Fix to zero values of downtime_arc outside the feasible time pairs
      # Specifically, x(t,t') = 0 if t' does not belong to 𝒢 = [t+DT, t+TC-1]
      # This is because DT is the minimum downtime, so there is no way x(t,t')=1 for t'<t+DT
      # and TC is the "time until cold" => if the generator starts afterwards, always has max cost
      #start_time = min(t + DT, T)
      #end_time = min(t + TC - 1, T)
      #for tmp_t in t+1:start_time
      #  fix(vars.downtime_arc[gi, t, tmp_t], 0.; force = true)
      #end
      #for tmp_t in end_time+1:T
      #  fix(vars.downtime_arc[gi, t, tmp_t], 0.; force = true)
      #end

      # Equation (59) in Kneuven et al. (2020)
      # Relate downtime_arc with switch_on
      # "switch_on[g,t] >= x_g(t',t) for all t' \in [t-TC+1, t-DT]"
      eqs.startup_at_t[gi, t] =
        @constraint(mip,
                    vars.switch_on[gi, t]
                    >= sum(vars.downtime_arc[gi,tmp_t,t]
                           for tmp_t in t-TC+1:t-DT if tmp_t >= 1)
                   )

      # Equation (60) in Kneuven et al. (2020)
      # "switch_off[g,t] >= x_g(t,t') for all t' \in [t+DT, t+TC-1]"
      eqs.shutdown_at_t[gi, t] =
        @constraint(mip,
                    vars.switch_off[gi, t]
                    >= sum(vars.downtime_arc[gi,t,tmp_t]
                           for tmp_t in t+DT:t+TC-1 if tmp_t <= T)
                   )

      # Objective function terms for start-up costs
      # Equation (61) in Kneuven et al. (2020)
      model.exprs.startup_cost[gi, t] = AffExpr()
      default_category = S
      if initial_time_shutdown > 0 && t + initial_time_shutdown - 1 < TC
        for s in 1:S-1
          # If off for x periods before, then belongs to category s
          # if -x+1 in [t-delay[s+1]+1,t-delay[s]]
          # or, equivalently, if total time off in [delay[s], delay[s+1]-1]
          # where total time off = t - 1 + initial_time_shutdown
          # (the -1 because not off for current time period)
          if t + initial_time_shutdown - 1 < g.startup_categories[s+1].delay
            default_category = s
            break # does not go into next category
          end
        end
      end
      add_to_expression!(model.exprs.startup_cost[gi, t],
                         vars.switch_on[gi, t],
                         g.startup_categories[default_category].cost)

      for s in 1:S-1
        # Objective function terms for start-up costs
        # Equation (61) in Kneuven et al. (2020)
        # Says to replace the cost of last category with cost of category s
        start_range = max((t - g.startup_categories[s + 1].delay + 1),1)
        end_range = min((t - g.startup_categories[s].delay),T-1)
        for tmp_t in start_range:end_range
          if (t < tmp_t + DT) || (t >= tmp_t + TC) # the second clause should never be true for s < S
            continue
          end
          add_to_expression!(model.exprs.startup_cost[gi, t],
                             vars.downtime_arc[gi,tmp_t,t],
                             g.startup_categories[s].cost - g.startup_categories[S].cost)
        end
      end # iterate over startup categories
      add_to_expression!(model.obj, model.exprs.startup_cost[gi, t])
    end # iterate over time
  end # iterate over units
end # add_startup_costs_KneOstWat20

function add_variables_KneOstWat20()
end # add_variables_startupcosts_KneOstWat20

# Kneuven, Ostrowski, and Watson, 2020
StartupCosts_KneOstWat20 = UCComponent(
  "StartupCosts_KneOstWat20",
  "Extended formulation using indicator variables.",
  StartupCosts,
  [:switch_on, :switch_off, :downtime_arc],
  [:startup_at_t, :shutdown_at_t],
  add_startupcosts_KneOstWat20,
  add_variables_KneOstWat20,
) # StartupCosts_KneOstWat20


##################################################
## Startup / shutdown limits

function add_startstop_limits_MorLatRam13(c::UCComponent,
                                          mip::JuMP.Model,
                                          model::UnitCommitmentModel2)
  vars, eqs = model.vars, model.eqs
  T = model.instance.time
  for t = 1:T
    for g in model.instance.units
      gi = g.name

      ## 2020-10-09 amk: added eqn (20) and check of g.min_uptime
      if g.min_uptime > 1 && t < T
        # Equation (20) in Kneuven et al. (2020)
        # UT > 1 required, to guarantee that vars.switch_on[gi, t] and vars.switch_off[gi, t+1] are not both = 1 at the same time
        eqs.startstop_limit[gi,t] =
          @constraint(mip,
                    vars.prod_above[gi, t] + vars.reserve[gi, t]
                    <= (g.max_power[t] - g.min_power[t]) * vars.is_on[gi, t]
                        - max(0, g.max_power[t] - g.startup_limit) * vars.switch_on[gi, t]
                        - max(0, g.max_power[t] - g.shutdown_limit) * vars.switch_off[gi, t+1])
      else
        ## Startup limits
        # Equation (21a) in Kneuven et al. (2020)
        # Proposed by Morales-España et al. (2013a)
        eqs.startup_limit[gi, t] =
          @constraint(mip,
                      vars.prod_above[gi, t] + vars.reserve[gi, t]
                      <= (g.max_power[t] - g.min_power[t]) * vars.is_on[gi, t]
                      - max(0, g.max_power[t] - g.startup_limit) * vars.switch_on[gi, t])

        ## Shutdown limits
        if t < T
          # Equation (21b) in Kneuven et al. (2020)
          # TODO different from what was in previous model, due to reserve variable
          # ax: ideally should have reserve_up and reserve_down variables
          #     i.e., the generator should be able to increase/decrease production as specified
          #     (this is a heuristic for a "robust" solution,
          #     in case there is an outage or a surge, and flow has to be redirected)
          # amk: if shutdown_limit is the max prod of generator in time period before shutting down,
          #      then it makes sense to count reserves, because otherwise, if reserves ≠ 0,
          #      then the generator will actually produce more than the limit
          eqs.shutdown_limit[gi, t] =
            @constraint(mip,
                        vars.prod_above[gi, t]
                        + (RESERVES_WHEN_SHUT_DOWN ? vars.reserve[gi, t] : 0.) # amk added
                        <= (g.max_power[t] - g.min_power[t]) * vars.is_on[gi, t]
                        - max(0, g.max_power[t] - g.shutdown_limit) * vars.switch_off[gi, t+1])
        end
      end # check if g.min_uptime > 1
    end # loop over units
  end # loop over time
end # add_startstop_limits_MorLatRam13

StartStopLimits_MorLatRam13 = UCComponent(
  "StartStopLimits_MorLatRam13",
  "Startup and shutdown limits from Morales-España et al. (2013a)."*
  " Eqns. (20), (21a), and (21b) in Kneuven et al. (2020).",
  GenerationLimits,
  [:is_on, :prod_above, :reserve, :switch_on, :switch_off],
  [:startstop_limit, :startup_limit, :shutdown_limit],
  add_startstop_limits_MorLatRam13,
  nothing
) # StartStopLimits_MorLatRam13


function add_startstop_limits_GenMorRam17(c::UCComponent,
                                          mip::JuMP.Model,
                                          model::UnitCommitmentModel2)
  vars, eqs = model.vars, model.eqs
  T = model.instance.time
  for g in model.instance.units
    gi = g.name
    known_initial_conditions = (g.initial_status != nothing && g.initial_power != nothing)

    if known_initial_conditions
      if g.initial_power > g.shutdown_limit
        #eqs.shutdown_limit[gi, 0] = @constraint(mip, vars.switch_off[gi, 1] <= 0)
        fix(vars.switch_off[gi, 1], 0.; force = true)
      end
    end

    for t = 1:T
      ## 2020-10-09 amk: added eqn (20) and check of g.min_uptime
      # Not present in (23) in Kneueven et al.
      if g.min_uptime > 1
        # Equation (20) in Kneuven et al. (2020)
        eqs.startstop_limit[gi,t] =
          @constraint(mip,
                      vars.prod_above[gi, t] + vars.reserve[gi, t]
                      <= (g.max_power[t] - g.min_power[t]) * vars.is_on[gi, t]
                          - max(0, g.max_power[t] - g.startup_limit) * vars.switch_on[gi, t]
                          - (t < T ? max(0, g.max_power[t] - g.shutdown_limit) * vars.switch_off[gi, t+1] : 0.)
                      )
      else
        ## Startup limits
        # Equation (23a) in Kneuven et al. (2020)
        eqs.startup_limit[gi, t] =
          @constraint(mip,
                      vars.prod_above[gi, t] + vars.reserve[gi, t]
                      <= (g.max_power[t] - g.min_power[t]) * vars.is_on[gi, t]
                          - max(0, g.max_power[t] - g.startup_limit) * vars.switch_on[gi, t]
                          - (t < T ? max(0, g.startup_limit - g.shutdown_limit) * vars.switch_off[gi, t+1] : 0.)
                      )

        ## Shutdown limits
        if t < T
          # Equation (23b) in Kneuven et al. (2020)
          eqs.shutdown_limit[gi, t] =
            @constraint(mip,
                        vars.prod_above[gi, t] + vars.reserve[gi, t]
                        <= (g.max_power[t] - g.min_power[t]) * vars.is_on[gi, t]
                            - (t < T ? max(0, g.max_power[t] - g.shutdown_limit) * vars.switch_off[gi, t+1] : 0.)
                            - max(0, g.shutdown_limit - g.startup_limit) * vars.switch_on[gi, t])
        end
      end # check if g.min_uptime > 1
    end # loop over time
  end # loop over units
end # add_startstop_limits_GenMorRam17

StartStopLimits_GenMorRam17 = UCComponent(
  "StartStopLimits_GenMorRam17",
  "Startup and shutdown limits from Gentile et al. (2017)."*
  " Eqns. (20), (23a), and (23b) in Kneuven et al. (2020).",
  GenerationLimits,
  [:is_on, :prod_above, :reserve, :switch_on, :switch_off],
  [:startstop_limit, :startup_limit, :shutdown_limit],
  add_startstop_limits_GenMorRam17,
  nothing
) # StartStopLimits_GenMorRam17


##################################################
## Shutdown costs + limits

function add_shutdown_costs_default(c::UCComponent,
                                    mip::JuMP.Model,
                                    model::UnitCommitmentModel2)
  T = model.instance.time
  for t = 1:T
    for g in model.instance.units
      gi = g.name

      shutdown_cost = 0.
      if shutdown_cost > 1e-7
        # Equation (62) in Kneuven et al. (2020)
        add_to_expression!(model.obj,
                           model.vars.switch_off[gi, t],
                           shutdown_cost)
      end
    end # loop over units
  end # loop over time
end # add_shutdown_costs_default

# Shutdown cost
DefaultShutdownCosts = UCComponent(
  "DefaultShutdownCosts",
  "Shutdown costs, (62) in Kneuven et al. (2020).",
  ShutdownCosts,
  [:switch_off],
  nothing,
  add_shutdown_costs_default,
  nothing
) # DefaultShutdownCosts


##################################################
## Network constraints

function add_network_constraints_default(c::UCComponent,
                                         mip::JuMP.Model,
                                         model::UnitCommitmentModel2)
  T = model.instance.time
  for lm in model.instance.lines
    for t in 1:T
    end # loop over time
  end # loop over lines
end # add_network constraints

DefaultNetworkConstraints = UCComponent(
  "DefaultNetworkConstraints",
  "Constraints for a linear approximation of the transmission network.",
  SystemConstraints,
  nothing,
  nothing,
  add_network_constraints_default,
  nothing
) # DefaultNetworkConstraints


##################################################
## Other contraints

function add_net_injection_default(c::UCComponent,
                                   mip::JuMP.Model,
                                   model::UnitCommitmentModel2)
  T = model.instance.time
  instance, vars, eqs, exprs = model.instance, model.vars, model.eqs, model.exprs

  if false
    for t in 1:T
      for b in instance.buses
        # Fixed load
        exprs.net_injection[b.name, t] = AffExpr(-b.load[t])

        # Load curtailment
        set_upper_bound(vars.curtail[b.name,t], b.load[t])
        add_to_expression!(exprs.net_injection[b.name, t], vars.curtail[b.name, t], 1.0)
        add_to_expression!(model.obj,
                           vars.curtail[b.name, t],
                           model.instance.power_balance_penalty[t])
      end # loop over buses

      for g in instance.units
        # Total production from this unit
        add_to_expression!(exprs.net_injection[g.bus.name, t], vars.prod_above[g.name, t], 1.0)
        add_to_expression!(exprs.net_injection[g.bus.name, t], vars.is_on[g.name, t], g.min_power[t])
      end # loop over units

      for ps in instance.price_sensitive_loads
        set_upper_bound(vars.loads[ps.name, t], ps.demand[t])
        add_to_expression!(exprs.net_injection[ps.bus.name, t], vars.loads[ps.name, t], -1.0)
        add_to_expression!(model.obj, vars.loads[ps.name, t], -ps.revenue[t])
      end # loop over price sensitive loads

      # Finally, now that the expression is set up, loop over buses and add the net_injection constraint
      for b in instance.buses
        model.eqs.net_injection_def[t, b.name] =
            @constraint(model.mip,
                        vars.net_injection[b.name, t]
                        == exprs.net_injection[b.name, t])
      end # loop over buses again

      # Overall net flow should be 0 across all buses
      model.eqs.power_balance[t] =
        @constraint(mip,
                    sum(vars.net_injection[b.name, t]
                        for b in instance.buses)
                    == 0)
    end # loop over time
  end # if 0 (commented out)

  for t in 1:T
    for ps in instance.price_sensitive_loads
      # We can optionally produce extra to meet these price-sensitive loads,
      # but importantly these are separate from the "fixed" demand at each bus
      add_to_expression!(model.obj, vars.loads[ps.name, t], -ps.revenue[t])
      set_upper_bound(vars.loads[ps.name, t], ps.demand[t])
    end # loop over price sensitive loads

    for b in instance.buses
      # If we fail to meet the demand, we suffer an (expensive) penalty
      add_to_expression!(model.obj,
                         vars.curtail[b.name, t],
                         instance.power_balance_penalty[t])

      set_upper_bound(vars.curtail[b.name,t], b.load[t])

      # At each bus, it holds that
      #   total fixed demand
      #     = [ total production ] - [ production allocated to price-sensitve loads ] + [ slack ]
      model.eqs.net_injection_def[t, b.name] =
        @constraint(mip,
                    vars.curtail[b.name,t]
                    + sum(g.min_power[t] * vars.is_on[g.name,t] + vars.prod_above[g.name,t]
                          for g in model.instance.units
                          if g.bus.name == b.name)
                    - sum(vars.loads[ps.name,t]
                          for ps in instance.price_sensitive_loads
                          if ps.bus.name == b.name)
                    - b.load[t]
                    == vars.net_injection[b.name, t])
    end # loop over buses

    # Overall net flow should be 0 across all buses
    model.eqs.power_balance[t] =
      @constraint(mip,
                  sum(vars.net_injection[b.name, t]
                      for b in instance.buses)
                  == 0)
  end # loop over time
end # add_net_injection_default

# flow balance and price-sensitive loads
DefaultNetInjection = UCComponent(
  "DefaultNetInjection",
  "Ensure demand is met.",
  SystemConstraints,
  [:curtail, :loads, :net_injection],
  [:net_injection_def, :power_balance],
  add_net_injection_default,
  nothing
) # DefaultNetInjection


##################################################
## Helpers
"""
Get union of all required variables in the components in `comps`.
"""
function get_required_variables(comps::Array{UCComponent}) :: Array{Symbol}
  vars = Array{Symbol,1}()
  for c in comps
    if isnothing(c.vars)
      continue
    end
    append!(vars, c.vars)
  end # iterate over components
  return unique(vars)
end # get_required_variables


"""
Get union of all required constraints in the components in `comps`.
"""
function get_required_constraints(comps::Array{UCComponent}) :: Array{Symbol}
  constrs = Array{Symbol,1}()
  for c in comps
    if isnothing(c.constrs)
      continue
    end
    append!(constrs, c.constrs)
  end # iterate over components
  return unique(constrs)
end # get_required_constraints


##################################################
## FORMULATIONS

#### Default formulation ####
"""
With references to Kneuven et al. (2020) where appropriate.

===
Variables:
  * u_g = :is_on
  * v_g = :switch_on
  * w_g = :switch_off
  * p'_g = :prod_above
  * p_g^l = :segprod
  * r_g = :reserve
  * s_R = :reserve_shortfall
  * s_n = :curtail (any of the fixed demand not met)
  * 𝛿_g^s = :startup --> different from tight formulation
  * :loads          --> production to meet price-sensitive demand
  * :net_injection  --> needed in enforce_transmission, created in DefaultNetInjection
                        (for a particular bus, total production - prod alloc to price-sensitive demand - total fixed demand)
  * :overflow       --> needed in enforce_transmission, created in DefaultRequiredComponent
  * :flow           --> created in enforce_transmission

===
Constraints:
  * Uptime/Downtime:
    * (2) = :binary_link,
    * (3a)+(4) = :min_uptime,
    * (3b)+(5) = :min_downtime,
    * (?) = :switch_on_off
  * Generation limits:
    * (18) = :prod_limit,
    * (20) = :startstop_limit,
    * (21a) = :startup_limit,
    * (21b) = :shutdown_limit
  * Ramp limits:
    * (26) = :ramp_up,
    * (27) = :ramp_down
  * Piecewise production:
    * (42) = :segprod_limit,
    * (43) = :prod_above_def,
    * (44) = add to :obj
  * Startup cost:
    * (54) = :startup_restrict,
    * (55) = :startup_choose,
    * (56) = add to :obj
  * Shutdown cost:
    * (62) = add to :obj
  * System constraints:
    * (68) = :min_reserve
    * kind of (65) = :power_balance
"""
DefaultFormulation = Vector{UCComponent}(
 [
  DefaultRequiredConstraints,   # (17)
  DefaultSystemConstraints,     # currently empty
  DefaultGenerationLimits,      # (18)
  PiecewiseProduction_Garver62, # (42), (43), (44)
  DefaultUpDownTime,            # (2), (3), (4), (5), (?) = :switch_on_off
  DefaultReserves,              # (68)
  Ramping_MorLatRam13,          # (26), (27)
  StartStopLimits_MorLatRam13,  # (20), (21a), (21b)
  StartupCosts_MorLatRam13,     # (54), (55), (56)
  DefaultShutdownCosts,         # (62)
  DefaultNetInjection,          # kind of (65) = :power_balance
 ]
) # DefaultFormulation

"""
Same as DefaultFormulation but with (45), a weaker version of constraints (42).
"""
SparseDefaultFormulation = Vector{UCComponent}(
 [
  DefaultRequiredConstraints,   # (17)
  DefaultSystemConstraints,     # currently empty
  DefaultGenerationLimits,      # (18)
  PiecewiseProduction_CarArr06, # (45), (43), (44)
  DefaultUpDownTime,            # (2), (3), (4), (5), (?) = :switch_on_off
  DefaultReserves,              # (68)
  Ramping_MorLatRam13,          # (26), (27)
  StartStopLimits_MorLatRam13,  # (20), (21a), (21b)
  StartupCosts_MorLatRam13,     # (54), (55), (56)
  DefaultShutdownCosts,         # (62)
  DefaultNetInjection,          # kind of (65) = :power_balance
 ]
) # SparseDefaultFormulation

#### Tight formulation ####
"""
From Kneuven et al. (2020), Table 3 on page 14.
Eqn :switch_on_off is used here but does not appear in the paper, I believe.

===
Variables using Kneuven et al. (2020) and UnitCommitment.jl notation:
  * u_g = :is_on
  * v_g = :switch_on
  * w_g = :switch_off
  * p'_g = :prod_above
  * p_g^l = :segprod
  * r_g = :reserve (replaces bar(p)'_g = p'_g + r_g in paper)
  * s_R = :reserve_shortfall
  * s_n = :curtail
  * x_g = :downtime_arc --> different from default formulation
  * :loads          --> production to meet price-sensitive demand
  * :net_injection  --> needed in enforce_transmission, created in DefaultNetInjection
                        (for a particular bus, total production - prod alloc to price-sensitive demand - total fixed demand)
  * :overflow       --> needed in enforce_transmission, created in DefaultRequiredComponent
  * :flow           --> created in enforce_transmission
  * p_{W,n}         --> renewables, accounted for implicitly in :prod_above
  * Θ_n             --> *missing*
  * f_k             --> *missing*
  * s_n^+           --> *missing*
  * s_n^-           --> *missing*

===
Objective: (69) = :obj

Constraints:
  * Uptime/Downtime:
    * (2) = :binary_link,
    * (3a)+(4) = :min_uptime,
    * (3b)+(5) = :min_downtime,
    * (?) = :switch_on_off
  * Generation limits:
    * (17) <=> nonneg on r_g = :reserve,
    * (23a) = :startup_limit,
    * (23b) = :shutdown_limit,
    * (38) = :str_prod_limit,
    * (40) if T_s^{RU} > UT_g - 2 = :prod_limit_ramp_up_extra_period,
    * (41) = :prod_limit_shutdown_trajectory,
    * ¿(20) = :startstop_limit?
  * Ramp limits:
    * (35) = :str_ramp_up,
    * (36) = :str_ramp_down
  * Piecewise production:
    * (43) = :prod_above_def,
    * (44) = add to :obj,
    * (46) if UT_g > 1 = :segprod_limit,
    * else (48a) and (48b) = :segprod_limita, :segprod_limitb
  * Startup cost:
    * (59) = :startup_at_t,
    * (60) = :shutdown_at_t,
    * (61) = add to :obj
  * Shudown cost: (62) = add to :obj
  * Network constraints:
    * (64) = network constraints, handled as lazy constraints by find_violations and enforce_transmission,
    * (65) = :power_balance and :net_injection_def,
    * (66) = positive and negative part of slack,    ** not modeled **
    * (67) = replaced by (68) = :min_reserve
"""
TightFormulation = Vector{UCComponent}(
 [
  DefaultRequiredConstraints,      # (17)
  DefaultSystemConstraints,        # currently empty
  DefaultGenerationLimits,         # (18)
  PiecewiseProduction_KneOstWat18, # (43), (44), (46), (48)
  DefaultUpDownTime,               # (2), (3), (4), (5), (?) = :switch_on_off
  DefaultReserves,                 # (68)
  Ramping_DamKucRajAta16,          # (35), (36)
  Ramping_PanGua16,                # (38), (40)
  StartStopLimits_GenMorRam17,     # (20), (23a), (23b)
  StartupCosts_KneOstWat20,        # (59), (60), (61)
  DefaultShutdownCosts,            # (62)
  DefaultNetInjection,             # take place of (65)
 ]
) # TightFormulation
