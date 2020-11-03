Linear Sensitivity Factors
==========================

UnitCommitment.jl includes a number of functions to compute typical linear sensitivity
factors, such as [Injection Shift Factors](@ref) and [Line Outage Distribution Factors](@ref). These sensitivity factors can be used to quickly compute DC power flows in both base and N-1 contigency scenarios.

Injection Shift Factors
-----------------------
Given a network with `B` buses and `L` transmission lines, the Injection Shift Factors (ISF) matrix is an `L`-by-`B` matrix which indicates much power flows through a certain transmission line when 1 MW of power is injected at bus `b` and withdrawn from the slack bus. For example, `isf[:l7, :b5]` indicates the amount of power (in MW) that flows through line `l7` when 1 MW of power is injected at bus `b5` and withdrawn from the slack bus.
This matrix is computed based on the DC linearization of power flow equations and does not include losses.
To compute the ISF matrix, the function `injection_shift_factors` can be used. It is necessary to specify the set of lines, buses and the slack bus:
```julia
using UnitCommitment
instance = UnitCommitment.load("ieee_rts/case14")
isf = UnitCommitment.injection_shift_factors(lines = instance.lines,
                                             buses = instance.buses,
                                             slack = :b14)
@show isf[:l7, :b5]
```