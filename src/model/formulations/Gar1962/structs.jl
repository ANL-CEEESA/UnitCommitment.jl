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
import ..StatusVarsFormulation

struct PwlCosts <: PiecewiseLinearCostsFormulation end
struct StatusVars <: StatusVarsFormulation end

end
