# UnitCommitment.jl

**UnitCommitment.jl** is an optimization package for the Security-Constrained Unit Commitment Problem (SCUC), a fundamental optimization problem in power systems which is used, for example, to clear the day-ahead electricity markets. The problem asks for the most cost-effective power generation schedule under a number of physical, operational and economic constraints.

### Package Components

* **Data Format:** The package proposes an extensible and fully-documented JSON-based data specification format for SCUC, developed in collaboration with Independent System Operators (ISOs), which describes the most important aspects of the problem.
* **Benchmark Instances:** The package provides a diverse collection of large-scale benchmark instances collected from the literature and extended to make them more challenging and realistic, based on publicly available data from ISOs.
* **Model Implementation**: The package provides a Julia/JuMP implementation of state-of-the-art formulations and solution methods for SCUC. Our goal is to keep this implementation up-to-date, as new methods are proposed in the literature.
* **Benchmark Tools:** The package provides automated benchmark scripts to accurately evaluate the performance impact of proposed code changes.

### Contents

* [Installation Guide](install.md)
* [Data Format Specification](format.md)

### Authors
* **Alinson Santos Xavier,** Argonne National Laboratory
* **Feng Qiu,** Argonne National Laboratory

### Collaborators
* **Yonghong Chen,** Midcontinent Independent System Operator
* **Feng Pan,** Pacific Northwest National Laboratory