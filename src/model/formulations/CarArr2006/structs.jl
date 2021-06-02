# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

"""
Formulation described in:

    Carrión, M., & Arroyo, J. M. (2006). A computationally efficient
    mixed-integer linear formulation for the thermal unit commitment problem.
    IEEE Transactions on power systems, 21(3), 1371-1378.
    DOI: https://doi.org/10.1109/TPWRS.2006.876672
"""
module CarArr2006

import ..PiecewiseLinearCostsFormulation

struct PwlCosts <: PiecewiseLinearCostsFormulation end

end
