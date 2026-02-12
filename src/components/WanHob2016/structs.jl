# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

Base.@kwdef mutable struct FlexirampReserve
    name::String
    amount::Vector{Float64}
    thermal_units::Vector
    shortfall_penalty::Float64
end

module WanHob2016
import ..UnitCommitmentExtension

"""

    struct FlexirampExt <: UnitCommitmentExtension end

Flexiramp formulation described in:

     B. Wang and B. F. Hobbs, "Real-Time Markets for Flexiramp: A Stochastic
     Unit Commitment-Based Analysis," in IEEE Transactions on Power Systems,
     vol. 31, no. 2, pp. 846-860, March 2016, doi: 10.1109/TPWRS.2015.2411268.

"""
struct FlexirampExt <: UnitCommitmentExtension end

end