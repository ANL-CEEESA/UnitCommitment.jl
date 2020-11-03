Benchmark Solver
================

Solving an instance of the Unit Commitment problem typically involves more
than simply building a Mixed-Integer Linear Programming and handing it over to the
solver. Since the number of transmission and N-1 security constraints can
easily exceed hundreds of millions for large instances of the problem, it is often
necessary to iterate between MILP optimization and contingency screening, so
that only necessary transmission constraints are added to the MILP.

`UnitCommitment.jl` includes a fast implementation of the contingency
screening method described in
[[1]](https://doi.org/10.1109/TPWRS.2019.2892620), which is able to
efficiently handle even ISO-scale instances of the problem. The method makes
use of Injection Shift Factors (ISFs) and Line Outage Distribution Factors
(LODFs) to model DC power flows and N-1 contingencies. If Julia is configured
to use multiple threads (through the environment variable `JULIA_NUM_THREADS`)
then multiple contingency scenarios are evaluated in parallel.

Usage
-----

To solve one of the benchmark instances using the included benchmark solver, use the method `UnitCommitment.solve`
as shown in the example below.

    julia> UnitCommitment.solve("ieee_rts/case118")
    [ Info: Loading instance: ieee_rts/case118
    [ Info:           54 units
    [ Info:          118 buses
    [ Info:          186 lines
    [ Info: Scaling problem (0.6 demands, 1.0 limits)...
    [ Info: Using Cbc as MILP solver (0.001 gap, 4 threads)
    [ Info: Computing sensitivity factors (0.001 ISF cutoff, 0.0001 LODF cutoff)...
    [ Info: Building MILP model (24 hours, 0.01 reserve)...
    [ Info: Optimizing...
    [ Info: Optimal value: 4.033106e+06
    [ Info: Solved in 8.73 seconds

With default settings, the solver does not consider any transmission or
security constraints, and the peak load is automatically set to 60% of the
installed capacity of the system. These, and many other settings, can be
configured using keyword arguments. See the reference section below for more
details. Sample usage:

    julia> UnitCommitment.solve("ieee_rts/case118", demand_scale=0.7, security=true)
    [ Info: Loading instance: ieee_rts/case118
    [ Info:           54 units
    [ Info:          118 buses
    [ Info:          186 lines
    [ Info: Scaling problem (0.7 demands, 1.0 limits)...
    [ Info: Using Cbc as MILP solver (0.001 gap, 4 threads)
    [ Info: Computing sensitivity factors (0.001 ISF cutoff, 0.0001 LODF cutoff)...
    [ Info: Building MILP model (24 hours, 0.01 reserve)...
    [ Info: Optimizing...
    [ Info: Verifying flow constraints...
    [ Info: Optimal value: 4.888740e+06
    [ Info: Solved in 4.50 seconds

When transmission or N-1 security constraints are activated, the solver uses an
iterative method to lazily enforce them. See [this
paper](https://doi.org/10.1109/TPWRS.2019.2892620) for a detailed description
of the method. Injection Shift Factors (ISF) and Line Outage Distribution
Factors (LODF) are used for the computation of DC power flows. 

!!! note
    Many of the benchmark instances were not originally designed for N-1
    security-constrained studies, and may become infeasible if these constraints
    are enforced. To avoid infeasibilities, the transmission limits can be
    increased through the keyword argument `limit_scale`.

By default, the MILP is solved using [Cbc, the COIN-OR Branch and Cut
solver](https://github.com/coin-or/Cbc). If `UnitCommitment` is loaded after
either [CPLEX](https://github.com/JuliaOpt/CPLEX.jl) or
[SCIP](https://github.com/SCIP-Interfaces/SCIP.jl), then these solvers will be
used instead. A detailed solver log can be displayed by setting `verbose=true`.

## Reference

```@docs
UnitCommitment.solve
```
