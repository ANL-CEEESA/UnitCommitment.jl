# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

abstract type TransmissionFormulation end
abstract type RampingFormulation end
abstract type PiecewiseLinearCostsFormulation end
abstract type StartupCostsFormulation end
abstract type StatusVarsFormulation end
abstract type ProductionVarsFormulation end

"""
    struct Formulation
        prod_vars::ProductionVarsFormulation
        pwl_costs::PiecewiseLinearCostsFormulation
        ramping::RampingFormulation
        startup_costs::StartupCostsFormulation
        status_vars::StatusVarsFormulation
        transmission::TransmissionFormulation
    end

Struct provided to `build_model` that holds various formulation components.

# Fields

- `prod_vars`: Formulation for the production decision variables
- `pwl_costs`: Formulation for the piecewise linear costs
- `ramping`: Formulation for ramping constraints
- `startup_costs`: Formulation for time-dependent start-up costs
- `status_vars`: Formulation for the status variables (e.g. `is_on`, `is_off`)
- `transmission`: Formulation for transmission and N-1 security constraints
"""
struct Formulation
    prod_vars::ProductionVarsFormulation
    pwl_costs::PiecewiseLinearCostsFormulation
    ramping::RampingFormulation
    startup_costs::StartupCostsFormulation
    status_vars::StatusVarsFormulation
    transmission::TransmissionFormulation

    function Formulation(;
        prod_vars::ProductionVarsFormulation = Gar1962.ProdVars(),
        pwl_costs::PiecewiseLinearCostsFormulation = KnuOstWat2018.PwlCosts(),
        ramping::RampingFormulation = MorLatRam2013.Ramping(),
        startup_costs::StartupCostsFormulation = MorLatRam2013.StartupCosts(),
        status_vars::StatusVarsFormulation = Gar1962.StatusVars(),
        transmission::TransmissionFormulation = ShiftFactorsFormulation(),
    )
        return new(
            prod_vars,
            pwl_costs,
            ramping,
            startup_costs,
            status_vars,
            transmission,
        )
    end
end

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
