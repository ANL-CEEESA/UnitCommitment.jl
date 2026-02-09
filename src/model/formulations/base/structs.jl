# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

abstract type TransmissionFormulation end
using JuMP

"""
	struct ShiftFactorsFormulation <: TransmissionFormulation
		isf_cutoff::Float64 = 0.005
		lodf_cutoff::Float64 = 0.001
		precomputed_isf=nothing
		precomputed_lodf=nothing
	end

Transmission formulation based on Injection Shift Factors (ISF) and Line
Outage Distribution Factors (LODF). Constraints are enforced in a lazy way.

Arguments
---------
- `precomputed_isf`:
	the injection shift factors matrix. If not provided, it will be computed.
- `precomputed_lodf`: 
	the line outage distribution factors matrix. If not provided, it will be
	computed.
- `isf_cutoff`: 
	the cutoff that should be applied to the ISF matrix. Entries with magnitude
	smaller than this value will be set to zero.
- `lodf_cutoff`: 
	the cutoff that should be applied to the LODF matrix. Entries with magnitude
	smaller than this value will be set to zero.
"""
struct ShiftFactorsFormulation <: TransmissionFormulation
    isf_cutoff::Float64
    lodf_cutoff::Float64
    precomputed_isf::Union{Nothing,Matrix{Float64}}
    precomputed_lodf::Union{Nothing,Matrix{Float64}}

    function ShiftFactorsFormulation(;
        isf_cutoff = 0.005,
        lodf_cutoff = 0.001,
        precomputed_isf = nothing,
        precomputed_lodf = nothing,
    )
        return new(isf_cutoff, lodf_cutoff, precomputed_isf, precomputed_lodf)
    end
end

"""
	struct PhaseAngleFormulation <: TransmissionFormulation
        phase_angle_limit::Float64 = pi
        bigM::Float64 = 1e6
	end
"""
Base.@kwdef struct PhaseAngleFormulation <: TransmissionFormulation
    phase_angle_limit::Float64 = pi
    bigM::Float64 = 1e6
end
