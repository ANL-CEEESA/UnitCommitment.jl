# UnitCommitmentFL.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

"""
Formulation described in:
    B. Wang and B. F. Hobbs, "Real-Time Markets for Flexiramp: A Stochastic 
    Unit Commitment-Based Analysis," in IEEE Transactions on Power Systems, 
    vol. 31, no. 2, pp. 846-860, March 2016, doi: 10.1109/TPWRS.2015.2411268.
"""
module WanHob2016

import ..RampingFormulation

struct Ramping <: RampingFormulation end

end
