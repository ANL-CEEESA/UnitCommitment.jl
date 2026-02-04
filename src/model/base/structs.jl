# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

abstract type PiecewiseLinearCostsFormulation end
abstract type RampingFormulation end
abstract type StartupCostsFormulation end
abstract type StartupShutdownLimitsFormulation end

struct BasePwlCosts <: PiecewiseLinearCostsFormulation end

Base.@kwdef struct Formulation
    pwl_costs::PiecewiseLinearCostsFormulation = KnuOstWat2018.PwlCosts()
    ramping::RampingFormulation = MorLatRam2013.Ramping()
    slimits::StartupShutdownLimitsFormulation =
        MorLatRam2013.StartupShutdownLimits()
end
