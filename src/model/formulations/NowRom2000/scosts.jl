# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

"""
    _add_startup_cost_eqs!

Based on Nowak and Römisch, 2000.
Introduces auxiliary startup cost variable, c_g^SU(t) for each time period,
and uses startup status variable, u_g(t);
there are exponentially many facets in this space,
but there is a linear-time separation algorithm (Brandenburg et al., 2017).
"""
function _add_startup_cost_eqs!(
    model::JuMP.Model,
    g::Unit,
    formulation::MorLatRam2013.StartupCosts,
)::Nothing
    error("Not implemented.")
end
