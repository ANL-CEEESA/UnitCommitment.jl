# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

abstract type PiecewiseLinearCostsFormulation end
abstract type RampingFormulation end
struct NoRamping <: RampingFormulation end
abstract type StartupCostsFormulation end
abstract type StartupShutdownLimitsFormulation end

struct BasePwlCosts <: PiecewiseLinearCostsFormulation end

Base.@kwdef mutable struct CostSegment
    mw::Vector{Float64}
    cost::Vector{Float64}
end

Base.@kwdef mutable struct StartupCategory
    delay::Int
    cost::Float64
end

Base.@kwdef mutable struct Reserve
    name::String
    type::Symbol                                # :spinning or :non_spinning
    amount::Vector{Float64}
    thermal_units::Vector
    shortfall_penalty::Float64
    parent::Union{Nothing,Reserve} = nothing    # cascading link
    descendants::Vector{Reserve} = Reserve[]    # precomputed during reading
end

Base.@kwdef mutable struct ThermalUnit
    name::String
    bus::Bus
    max_power::Vector{Float64}
    min_power::Vector{Float64}
    must_run::Vector{Bool}
    min_power_cost::Vector{Float64}
    cost_segments::Vector{CostSegment}
    min_uptime::Int
    min_downtime::Int
    ramp_up_limit::Float64
    ramp_down_limit::Float64
    startup_limit::Float64
    shutdown_limit::Float64
    initial_status::Union{Int,Nothing}
    initial_power::Union{Float64,Nothing}
    startup_categories::Vector{StartupCategory}
    shutdown_cost::Float64 = 0.0
    reserves::Vector{Reserve}
    non_spinning_capacity::Float64
    commitment_status::Vector{Union{Bool,Nothing}}
    invest::Float64
    qmin::Float64 = 0.0
    qmax::Float64 = 0.0
end

Base.@kwdef struct ThermalExt <: UnitCommitmentExtension
    pwl_costs::PiecewiseLinearCostsFormulation = KnuOstWat2018.PwlCosts()
    ramping::RampingFormulation = MorLatRam2013.Ramping()
    slimits::StartupShutdownLimitsFormulation =
        MorLatRam2013.StartupShutdownLimits()
end
