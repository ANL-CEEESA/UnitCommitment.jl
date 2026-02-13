# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

"""
Rectangular AC power flow formulation.

Voltage is represented using real and imaginary components (vr, vi).
"""
module ACR

import ..ACFormulation

struct Formulation <: ACFormulation end

end
