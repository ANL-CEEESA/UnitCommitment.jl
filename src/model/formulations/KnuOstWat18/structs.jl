# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

"""
Formulation described in:

    Knueven, B., Ostrowski, J., & Watson, J. P. (2018). Exploiting identical
    generators in unit commitment. IEEE Transactions on Power Systems, 33(4),
    4496-4507.
"""
struct KnuOstWat18 <: PiecewiseLinearCostsFormulation end
