# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

Base.@kwdef struct PhaseAngleTransmissionExt <: DCTransmissionExt
    phase_angle_limit::Float64 = 1e6
    big_m::Float64 = 1e6
end
