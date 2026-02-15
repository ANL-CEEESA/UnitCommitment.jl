# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

Base.@kwdef struct ShiftFactorsTransmissionExt <: TransmissionExtension
    isf_cutoff::Float64 = 0.005
    lodf_cutoff::Float64 = 0.001
    lazy::Bool = false
end
