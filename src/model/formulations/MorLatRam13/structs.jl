# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

"""
Formulation described in:

    Morales-España, G., Latorre, J. M., & Ramos, A. (2013). Tight and compact
    MILP formulation for the thermal unit commitment problem. IEEE Transactions
    on Power Systems, 28(4), 4897-4908.
"""
struct MorLatRam13 <: RampingFormulation end
