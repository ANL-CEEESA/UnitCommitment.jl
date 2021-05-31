# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

"""
Formulation described in:

    Damcı-Kurt, P., Küçükyavuz, S., Rajan, D., & Atamtürk, A. (2016). A polyhedral
    study of production ramping. Mathematical Programming, 158(1), 175-205.
"""
struct DamKucRajAta16 <: RampingFormulation end
