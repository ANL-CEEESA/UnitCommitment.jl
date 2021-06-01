# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

"""
Formulation described in:

    Pan, K., & Guan, Y. (2016). Strong formulations for multistage stochastic
    self-scheduling unit commitment. Operations Research, 64(6), 1482-1498.
"""
struct PanGua2016 <: RampingFormulation end
