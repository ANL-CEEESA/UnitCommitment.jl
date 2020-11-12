<a href="https://github.com/ANL-CEEESA/UnitCommitment.jl/actions?query=workflow%3ATest+branch%3Adev"><img src="https://github.com/iSoron/UnitCommitment.jl/workflows/Tests/badge.svg"></img></a>
<a href="https://github.com/ANL-CEEESA/UnitCommitment.jl/actions?query=workflow%3ABenchmark+branch%3Adev"><img src="https://github.com/iSoron/UnitCommitment.jl/workflows/Benchmark/badge.svg"></img></a>
<a href="https://zenodo.org/badge/latestdoi/263667075"><img src="https://zenodo.org/badge/263667075.svg" alt="DOI"></a>



# UnitCommitment.jl

**UnitCommitment.jl** (UC.jl) is an optimization package for the Security-Constrained Unit Commitment Problem (SCUC), a fundamental optimization problem in power systems used, for example, to clear the day-ahead electricity markets. The package provides benchmark instances for the problem and JuMP implementations of state-of-the-art mixed-integer programming formulations.

### Package Components

* **Data Format:** The package proposes an extensible and fully-documented JSON-based data specification format for SCUC, developed in collaboration with Independent System Operators (ISOs), which describes the most important aspects of the problem. The format supports all the most common generator characteristics (including ramping, piecewise-linear production cost curves and time-dependent startup costs), as well as operating reserves, price-sensitive loads, transmission networks and contingencies.
* **Benchmark Instances:** The package provides a diverse collection of large-scale benchmark instances collected from the literature and extended to make them more challenging and realistic.
* **Model Implementation**: The package provides a Julia/JuMP implementation of state-of-the-art formulations and solution methods for SCUC. Our goal is to keep this implementation up-to-date, as new methods are proposed in the literature.
* **Benchmark Tools:** The package provides automated benchmark scripts to accurately evaluate the performance impact of proposed code changes.

### Documentation

* [Usage](https://anl-ceeesa.github.io/UnitCommitment.jl/0.1/usage/)
* [Data Format](https://anl-ceeesa.github.io/UnitCommitment.jl/0.1/format/)

### Authors
* **Alinson Santos Xavier** (Argonne National Laboratory)
* **Feng Qiu** (Argonne National Laboratory)

### Acknowledgments

* We would like to thank **Aleksandr M. Kazachkov** (University of Florida), **Yonghong Chen** (Midcontinent Independent System Operator), **Feng Pan** (Pacific Northwest National Laboratory) for valuable feedback on early versions of this package.

* Based upon work supported by **Laboratory Directed Research and Development** (LDRD) funding from Argonne National Laboratory, provided by the Director, Office of Science, of the U.S. Department of Energy under Contract No. DE-AC02-06CH11357.

### License

Released under the modified BSD license. See `LICENSE.md` for more details.

### Citing

If you find UC.jl useful in your research, we would appreciate a citation such as:

```
@software{ucjl,
  author       = {Alinson S. Xavier and Feng Qiu},
  title        = {{UnitCommitment.jl: A Julia/JuMP Optimization Package
                 for the Security-Constrained Unit Commitment Problem}},
  month        = nov,
  year         = 2020,
  publisher    = {Zenodo},
  version      = {v0.1.0},
  doi          = {10.5281/zenodo.4269874},
  url          = {https://doi.org/10.5281/zenodo.4269874}
}
```
