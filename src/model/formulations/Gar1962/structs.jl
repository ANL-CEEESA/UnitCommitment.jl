# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

"""
Formulation described in:

    Garver, L. L. (1962). Power generation scheduling by integer
    programming-development of theory. Transactions of the American Institute
    of Electrical Engineers. Part III: Power Apparatus and Systems, 81(3), 730-734.
    DOI: https://doi.org/10.1109/AIEEPAS.1962.4501405

"""
module Gar1962

import ..PiecewiseLinearCostsFormulation
import ..ProductionVarsFormulation
import ..StatusVarsFormulation

"""
Variables
---
* `prod_above`:
        [gen, t];
        *production above minimum required level*;
        lb: 0, ub: Inf.
        KnuOstWat2020: `p'_g(t)`
* `segprod`:
        [gen, segment, t];
        *how much generator produces on cost segment in time t*;
        lb: 0, ub: Inf.
        KnuOstWat2020: `p_g^l(t)`
"""
struct ProdVars <: ProductionVarsFormulation end

struct PwlCosts <: PiecewiseLinearCostsFormulation end

"""
Variables
---
* `is_on`:
        [gen, t];
        *is generator on at time t?*
        lb: 0, ub: 1, binary.
        KnuOstWat2020: `u_g(t)`
* `switch_on`:
        [gen, t];
        *indicator that generator will be turned on at t*;
        lb: 0, ub: 1, binary.
        KnuOstWat2020: `v_g(t)`
* `switch_off`: binary;
        [gen, t];
        *indicator that generator will be turned off at t*;
        lb: 0, ub: 1, binary.
        KnuOstWat2020: `w_g(t)`

Arguments
---
* `fix_vars_via_constraint`:
        indicator for whether to set vars to a constant using `fix` or by adding an explicit constraint
        (particulary useful for debugging purposes).
"""
struct StatusVars <: StatusVarsFormulation
    fix_vars_via_constraint::Bool

    StatusVars() = new(false)
end

end
