# Installation Guide

This package was tested and developed with [Julia 1.5](https://julialang.org/). To install Julia, please follow the [installation guide on their website](https://julialang.org/downloads/platform.html). To install `UnitCommitment.jl`, run the Julia interpreter, type `]` to open the package manager, then type:

```text
pkg> add https://github.com/ANL-CEEESA/UnitCommitment.jl.git
```

To test that the package has been correctly installed, run:

```text
pkg> test UnitCommitment
```

If all tests pass, the package should now be ready to be used by any Julia script on the machine. To try it out in the julia interpreter hit `backspace` to return to the regular interpreter, and type the following command:
```julia
using UnitCommitment
```
