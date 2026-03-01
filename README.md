<h1 align="center">UnitCommitment.jl</h1>
<p align="center">
  <a href="https://doi.org/10.5281/zenodo.4269874">
    <img src="https://zenodo.org/badge/doi/10.5281/zenodo.4269874.svg" alt="DOI"></img>
  </a>
  <a href="https://github.com/ANL-CEEESA/UnitCommitment.jl/releases/">
    <img src="https://img.shields.io/github/v/release/ANL-CEEESA/UnitCommitment.jl?include_prereleases&label=pre-release">
  </a>
  <a href="https://github.com/ANL-CEEESA/UnitCommitment.jl/discussions">
    <img src="https://img.shields.io/badge/GitHub-Discussions-%23fc4ebc" />
  </a>
</p>

**UnitCommitment.jl** (UC.jl) is an extensible Julia/JuMP optimization package for the Security-Constrained Unit Commitment problem (SCUC), a fundamental optimization problem in power systems used, for example, to clear day-ahead electricity markets. The package provides a standardized data format, benchmark instances, state-of-the-art MIP formulations, and a modular architecture in which every grid component is an independent, swappable extension.

## Package Components

* **Data Format.** An extensible, fully-documented JSON-based data format for SCUC, developed in collaboration with Independent System Operators (ISOs). The format covers thermal generators, battery storage, profiled generators, price-sensitive loads, virtual transactions, transmission branches (including contingencies), shunt devices, interface limits, and reserves (spinning, non-spinning, flexiramp). A built-in migration system upgrades instances from older format versions automatically.

* **Benchmark Instances.** Over 19,000 instances spanning 14 to 13,659 buses and 12 to 4,092 generators, collected from the literature and converted into the common format. The ML-augmented MATPOWER instances provide 365 daily variations per network, generated using data-driven methods to make them more challenging and realistic.

* **Modular Architecture.** Every grid component is an independent extension that implements a common lifecycle: data reading, model building, solution extraction, and validation. Eight extensions ship by default; users can replace any of them (e.g., swap DC shift factors for AC power flow) or add new ones (e.g., flexiramp reserves) at read time, without modifying source code.

* **Formulations.** State-of-the-art MIP formulations are provided, including multiple ramping formulations ([ArrCon2000], [MorLatRam2013], [DamKucRajAta2016], [PanGua2016]), piecewise-linear cost formulations ([KnuOstWat2018]), and four transmission models: copperplate, DC shift factors with lazy N-1 contingency screening ([XavQiuWanThi2019]), DC phase angles, and full nonlinear AC power flow in rectangular or polar form.

* **Solution Methods.** Problems can be solved as a single MILP, decomposed over a sliding time window for long horizons, or solved under uncertainty via two-stage stochastic programming with progressive hedging and MPI parallelization.

* **Market Clearing and Pricing.** Day-ahead and real-time two-settlement market simulation is supported, with commitment status mapping, sub-hourly time alignment, and chained initial conditions across real-time periods. Locational marginal prices are computed automatically and decomposed into energy and congestion components.

* **Validation.** An independent feasibility checker recomputes every operational constraint — production limits, ramp rates, minimum up/downtime, reserve requirements, energy balance, branch flows — from the instance data alone, without inspecting the optimization model. This catches formulation bugs and can verify solutions produced by external solvers. Both DC and AC implementations are cross-validated against [PowerModels.jl](https://github.com/lanl-ansi/PowerModels.jl) on standard IEEE test systems.

[ArrCon2000]: https://doi.org/10.1109/59.871739
[DamKucRajAta2016]: https://doi.org/10.1007/s10107-015-0919-9
[KnuOstWat2018]: https://doi.org/10.1109/TPWRS.2017.2783850
[MorLatRam2013]: https://doi.org/10.1109/TPWRS.2013.2251373
[PanGua2016]: https://doi.org/10.1287/opre.2016.1520
[XavQiuWanThi2019]: https://doi.org/10.1109/TPWRS.2019.2892620

## Quick Start

```julia
using UnitCommitment, HiGHS

# Read a benchmark instance (automatically downloaded and cached)
instance = UnitCommitment.read_benchmark("matpower/case118/2017-02-01")

# Build and solve the optimization model
model = build_model(instance, optimizer = HiGHS.Optimizer)
optimize!(model)

# Extract and export the solution
sol = solution(model)
UnitCommitment.write("sol.json", solution)
```

## Customization

Extensions are passed at read time to replace defaults or add new components:

```julia
import UnitCommitment:
    ACTransmissionExt,
    ACRectangular,
    ThermalExt,
    DamKucRajAta2016,
    WanHob2016

# Use AC power flow instead of the default DC shift factors
instance = UnitCommitment.read_benchmark(
    "matpower/case118/2017-02-01",
    extensions = [ACTransmissionExt(formulation = ACRectangular())],
)

# Customize thermal formulations and add flexiramp reserves
instance = UnitCommitment.read(
    "my_instance.json",
    extensions = [
        ThermalExt(ramping = DamKucRajAta2016.Ramping()),
        WanHob2016.FlexirampExt(),
    ],
)
```

The underlying JuMP model can also be modified directly before solving:

```julia
using JuMP

model = UnitCommitment.build_model(instance, optimizer = HiGHS.Optimizer)

@constraint(
    model.inner,
    model.inner[:is_on]["g3", 1] + model.inner[:is_on]["g4", 1] <= 1,
)

UnitCommitment.optimize!(model)
```

## Documentation

Full documentation: https://anl-ceeesa.github.io/UnitCommitment.jl/

## Authors
* **Alinson S. Xavier** (Argonne National Laboratory)
* **Aleksandr M. Kazachkov** (University of Florida)
* **Ogün Yurdakul** (Technische Universität Berlin)
* **Jun He** (Purdue University)
* **Weihang Ren** (University of Florida)
* **Feng Qiu** (Argonne National Laboratory)

## Acknowledgments

* We would like to thank **Yonghong Chen** (Midcontinent Independent System Operator), **Feng Pan** (Pacific Northwest National Laboratory) for valuable feedback on early versions of this package.

* Based upon work supported by **Laboratory Directed Research and Development** (LDRD) funding from Argonne National Laboratory, provided by the Director, Office of Science, of the U.S. Department of Energy under Contract No. DE-AC02-06CH11357

* Based upon work supported by the **U.S. Department of Energy Advanced Grid Modeling Program** under Grant DE-OE0000875.

## Citing

If you use UnitCommitment.jl in your research (instances, models or algorithms), we kindly request that you cite the package as follows:

* **Alinson S. Xavier, Aleksandr M. Kazachkov, Ogün Yurdakul, Jun He, Feng Qiu**. "UnitCommitment.jl: A Julia/JuMP Optimization Package for Security-Constrained Unit Commitment (Version 0.4)". Zenodo (2024). [DOI: 10.5281/zenodo.4269874](https://doi.org/10.5281/zenodo.4269874).

If you use the instances, we additionally request that you cite the original sources, as described in the documentation.

## License

```text
UnitCommitment.jl: A Julia/JuMP Optimization Package for Security-Constrained Unit Commitment
Copyright © 2020-2026, UChicago Argonne, LLC. All Rights Reserved.

Redistribution and use in source and binary forms, with or without modification, are permitted
provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this list of
   conditions and the following disclaimer.
2. Redistributions in binary form must reproduce the above copyright notice, this list of
   conditions and the following disclaimer in the documentation and/or other materials provided
   with the distribution.
3. Neither the name of the copyright holder nor the names of its contributors may be used to
   endorse or promote products derived from this software without specific prior written
   permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR
IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY
AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR
CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
POSSIBILITY OF SUCH DAMAGE.
```
