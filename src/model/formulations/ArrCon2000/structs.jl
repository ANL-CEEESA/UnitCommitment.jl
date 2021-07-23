# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

"""
Formulation described in:

    Arroyo, J. M., & Conejo, A. J. (2000). Optimal response of a thermal unit
    to an electricity spot market. IEEE Transactions on power systems, 15(3), 
    1098-1104. DOI: https://doi.org/10.1109/59.871739
"""
module ArrCon2000

import ..RampingFormulation

"""
Constraints
---
* `eq_ramp_up`: Equation (24) in Knueven et al. (2020)
* `eq_ramp_down`: Equation (25) in Knueven et al. (2020)
"""
struct Ramping <: RampingFormulation end

end
