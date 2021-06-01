# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

"""
Formulation described in:

    Garver, L. L. (1962). Power generation scheduling by integer
    programming-development of theory. Transactions of the American Institute
    of Electrical Engineers. Part III: Power Apparatus and Systems, 81(3), 730-734.

"""
struct Gar62 <: PiecewiseLinearCostsFormulation end
