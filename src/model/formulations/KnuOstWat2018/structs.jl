# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

"""
Formulation described in:

    Knueven, B., Ostrowski, J., & Watson, J. P. (2018). Exploiting identical
    generators in unit commitment. IEEE Transactions on Power Systems, 33(4),
    4496-4507. DOI: https://doi.org/10.1109/TPWRS.2017.2783850
"""
module KnuOstWat2018

import ..PiecewiseLinearCostsFormulation

struct PwlCosts <: PiecewiseLinearCostsFormulation end

end
