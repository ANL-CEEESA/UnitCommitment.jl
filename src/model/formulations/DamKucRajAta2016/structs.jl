# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

"""
Formulation described in:

    Damcı-Kurt, P., Küçükyavuz, S., Rajan, D., & Atamtürk, A. (2016). A polyhedral
    study of production ramping. Mathematical Programming, 158(1), 175-205.
    DOI: https://doi.org/10.1007/s10107-015-0919-9
"""
module DamKucRajAta2016

import ..RampingFormulation

struct Ramping <: RampingFormulation end

end
