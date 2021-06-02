# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

"""
Formulation described in:

    Morales-España, G., Latorre, J. M., & Ramos, A. (2013). Tight and compact
    MILP formulation for the thermal unit commitment problem. IEEE Transactions
    on Power Systems, 28(4), 4897-4908. DOI: https://doi.org/10.1109/TPWRS.2013.2251373
"""
module MorLatRam2013

import ..RampingFormulation
import ..StartupCostsFormulation

struct Ramping <: RampingFormulation end
struct StartupCosts <: StartupCostsFormulation end

end
