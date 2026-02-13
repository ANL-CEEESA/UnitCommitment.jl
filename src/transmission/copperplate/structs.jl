# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

Base.@kwdef struct CopperPlateTransmissionExt <: UnitCommitmentExtension end

extension_slot(::CopperPlateTransmissionExt) = :transmission
