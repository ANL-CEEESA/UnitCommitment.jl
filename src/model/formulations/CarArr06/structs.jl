# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

"""
Formulation described in:

    Carrión, M., & Arroyo, J. M. (2006). A computationally efficient
    mixed-integer linear formulation for the thermal unit commitment problem.
    IEEE Transactions on power systems, 21(3), 1371-1378.
"""
struct CarArr06 <: PiecewiseLinearCostsFormulation end
