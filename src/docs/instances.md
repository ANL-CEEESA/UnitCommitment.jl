# Instances

UnitCommitment.jl provides a collection of large-scale benchmark instances collected
from the literature in a [standard data format](format.md) and, in some cases, extended with realistic unit commitment data, produced by data-driven methods. If you use these instances in your research, we request that you cite UnitCommitment.jl, as well as the original sources (as listed below).

Raw instances files are [available at our GitHub repository](https://github.com/ANL-CEEESA/UnitCommitment.jl/tree/dev/instances). Benchmark instances can also be loaded with
`UnitCommitment.read_benchmark(name)`, as explained in the [usage section](usage.md), where `name` is one of the names below.

## 1. PGLIB-UC Instances

[PGLIB-UC](https://github.com/power-grid-lib/pglib-uc) is a benchmark library curated and maintained by the [IEEE PES Task Force on Benchmarks for Validation of Emerging Power System Algorithms](https://power-grid-lib.github.io/).


### 1.1 PGLIB-UC/California

Test cases based on publicly available data from the California ISO. For more details, see [PGLIB-UC case file overview](https://github.com/power-grid-lib/pglib-uc).

| Name | Buses | Generators | Lines | Contingencies | References |
|------|-------|------------|-------|---------------|--------|
| `pglib-uc/ca/2014-09-01_reserves_0` | 1 | 610 | 0 | 0 | [KnOsWa18], [KrHiOn12]
| `pglib-uc/ca/2014-09-01_reserves_1` | 1 | 610 | 0 | 0 | [KnOsWa18], [KrHiOn12]
| `pglib-uc/ca/2014-09-01_reserves_3` | 1 | 610 | 0 | 0 | [KnOsWa18], [KrHiOn12]
| `pglib-uc/ca/2014-09-01_reserves_5` | 1 | 610 | 0 | 0 | [KnOsWa18], [KrHiOn12]
| `pglib-uc/ca/2014-12-01_reserves_0` | 1 | 610 | 0 | 0 | [KnOsWa18], [KrHiOn12]
| `pglib-uc/ca/2014-12-01_reserves_1` | 1 | 610 | 0 | 0 | [KnOsWa18], [KrHiOn12]
| `pglib-uc/ca/2014-12-01_reserves_3` | 1 | 610 | 0 | 0 | [KnOsWa18], [KrHiOn12]
| `pglib-uc/ca/2014-12-01_reserves_5` | 1 | 610 | 0 | 0 | [KnOsWa18], [KrHiOn12]
| `pglib-uc/ca/2015-03-01_reserves_0` | 1 | 610 | 0 | 0 | [KnOsWa18], [KrHiOn12]
| `pglib-uc/ca/2015-03-01_reserves_1` | 1 | 610 | 0 | 0 | [KnOsWa18], [KrHiOn12]
| `pglib-uc/ca/2015-03-01_reserves_3` | 1 | 610 | 0 | 0 | [KnOsWa18], [KrHiOn12]
| `pglib-uc/ca/2015-03-01_reserves_5` | 1 | 610 | 0 | 0 | [KnOsWa18], [KrHiOn12]
| `pglib-uc/ca/2015-06-01_reserves_0` | 1 | 610 | 0 | 0 | [KnOsWa18], [KrHiOn12]
| `pglib-uc/ca/2015-06-01_reserves_1` | 1 | 610 | 0 | 0 | [KnOsWa18], [KrHiOn12]
| `pglib-uc/ca/2015-06-01_reserves_3` | 1 | 610 | 0 | 0 | [KnOsWa18], [KrHiOn12]
| `pglib-uc/ca/2015-06-01_reserves_5` | 1 | 610 | 0 | 0 | [KnOsWa18], [KrHiOn12]
| `pglib-uc/ca/Scenario400_reserves_0` | 1 | 611 | 0 | 0 | [KnOsWa18], [KrHiOn12]
| `pglib-uc/ca/Scenario400_reserves_1` | 1 | 611 | 0 | 0 | [KnOsWa18], [KrHiOn12]
| `pglib-uc/ca/Scenario400_reserves_3` | 1 | 611 | 0 | 0 | [KnOsWa18], [KrHiOn12]
| `pglib-uc/ca/Scenario400_reserves_5` | 1 | 611 | 0 | 0 | [KnOsWa18], [KrHiOn12]


### 1.2 PGLIB-UC/FERC

Test cases based on publicly available unit commitment test instance from the Federal Energy Regulatory Commission. For more details, see [PGLIB-UC case file overview](https://github.com/power-grid-lib/pglib-uc).

| Name | Buses | Generators | Lines | Contingencies | References |
|------|-------|------------|-------|---------------|--------|
| `pglib-uc/ferc/2015-01-01_hw` | 1 | 935 | 0 | 0 | [KnOsWa18]
| `pglib-uc/ferc/2015-01-01_lw` | 1 | 935 | 0 | 0 | [KnOsWa18]
| `pglib-uc/ferc/2015-02-01_hw` | 1 | 935 | 0 | 0 | [KnOsWa18]
| `pglib-uc/ferc/2015-02-01_lw` | 1 | 935 | 0 | 0 | [KnOsWa18]
| `pglib-uc/ferc/2015-03-01_hw` | 1 | 935 | 0 | 0 | [KnOsWa18]
| `pglib-uc/ferc/2015-03-01_lw` | 1 | 935 | 0 | 0 | [KnOsWa18]
| `pglib-uc/ferc/2015-04-01_hw` | 1 | 979 | 0 | 0 | [KnOsWa18]
| `pglib-uc/ferc/2015-04-01_lw` | 1 | 979 | 0 | 0 | [KnOsWa18]
| `pglib-uc/ferc/2015-05-01_hw` | 1 | 979 | 0 | 0 | [KnOsWa18]
| `pglib-uc/ferc/2015-05-01_lw` | 1 | 979 | 0 | 0 | [KnOsWa18]
| `pglib-uc/ferc/2015-06-01_hw` | 1 | 979 | 0 | 0 | [KnOsWa18]
| `pglib-uc/ferc/2015-06-01_lw` | 1 | 979 | 0 | 0 | [KnOsWa18]
| `pglib-uc/ferc/2015-07-01_hw` | 1 | 979 | 0 | 0 | [KnOsWa18]
| `pglib-uc/ferc/2015-07-01_lw` | 1 | 979 | 0 | 0 | [KnOsWa18]
| `pglib-uc/ferc/2015-08-01_hw` | 1 | 979 | 0 | 0 | [KnOsWa18]
| `pglib-uc/ferc/2015-08-01_lw` | 1 | 979 | 0 | 0 | [KnOsWa18]
| `pglib-uc/ferc/2015-09-01_hw` | 1 | 979 | 0 | 0 | [KnOsWa18]
| `pglib-uc/ferc/2015-09-01_lw` | 1 | 979 | 0 | 0 | [KnOsWa18]
| `pglib-uc/ferc/2015-10-01_hw` | 1 | 935 | 0 | 0 | [KnOsWa18]
| `pglib-uc/ferc/2015-10-01_lw` | 1 | 935 | 0 | 0 | [KnOsWa18]
| `pglib-uc/ferc/2015-11-02_hw` | 1 | 935 | 0 | 0 | [KnOsWa18]
| `pglib-uc/ferc/2015-11-02_lw` | 1 | 935 | 0 | 0 | [KnOsWa18]
| `pglib-uc/ferc/2015-12-01_hw` | 1 | 935 | 0 | 0 | [KnOsWa18]
| `pglib-uc/ferc/2015-12-01_lw` | 1 | 935 | 0 | 0 | [KnOsWa18]


### 1.3 PGLIB-UC/RTS-GMLC

[RTS-GMLC](https://github.com/GridMod/RTS-GMLC) is an updated version of the RTS-96 test system produced by the United States Department of Energy's [Grid Modernization Laboratory Consortium](https://gmlc.doe.gov/). The PGLIB-UC/RTS-GMLC instances are modified versions of the original RTS-GMLC instances, with modified ramp-rates and without a transmission network. For more details, see [PGLIB-UC case file overview](https://github.com/power-grid-lib/pglib-uc).

| Name | Buses | Generators | Lines | Contingencies | References |
|------|-------|------------|-------|---------------|--------|
| `pglib-uc/rts_gmlc/2020-01-27` | 1 | 154 | 0 | 0 | [BaBlEh19]
| `pglib-uc/rts_gmlc/2020-02-09` | 1 | 154 | 0 | 0 | [BaBlEh19]
| `pglib-uc/rts_gmlc/2020-03-05` | 1 | 154 | 0 | 0 | [BaBlEh19]
| `pglib-uc/rts_gmlc/2020-04-03` | 1 | 154 | 0 | 0 | [BaBlEh19]
| `pglib-uc/rts_gmlc/2020-05-05` | 1 | 154 | 0 | 0 | [BaBlEh19]
| `pglib-uc/rts_gmlc/2020-06-09` | 1 | 154 | 0 | 0 | [BaBlEh19]
| `pglib-uc/rts_gmlc/2020-07-06` | 1 | 154 | 0 | 0 | [BaBlEh19]
| `pglib-uc/rts_gmlc/2020-08-12` | 1 | 154 | 0 | 0 | [BaBlEh19]
| `pglib-uc/rts_gmlc/2020-09-20` | 1 | 154 | 0 | 0 | [BaBlEh19]
| `pglib-uc/rts_gmlc/2020-10-27` | 1 | 154 | 0 | 0 | [BaBlEh19]
| `pglib-uc/rts_gmlc/2020-11-25` | 1 | 154 | 0 | 0 | [BaBlEh19]
| `pglib-uc/rts_gmlc/2020-12-23` | 1 | 154 | 0 | 0 | [BaBlEh19]

## 2. MATPOWER

[MATPOWER](https://github.com/MATPOWER/matpower) is an open-source package for solving power flow problems in MATLAB and Octave. It contains a number of power flow test cases, which have been widely used in the power systems literature.

Because most MATPOWER test cases were originally designed for power flow studies, they lack a number of important unit commitment parameters, such as time-varying loads, production cost curves, ramp limits, reserves and initial conditions. The test cases included in UnitCommitment.jl are extended versions of the original MATPOWER test cases, modified as following:

* **Production cost** curves were generated using a data-driven approach, based on publicly available data. More specifically, machine learning models were trained to predict typical production cost curves, for each day of the year, based on a generator's maximum and minimum power output.

* **Load profiles** were generated using a similar data-driven approach.

* **Ramp-up, ramp-down, startup and shutdown rates** were set to fixed proportion of the generator's maximum output.

* **Minimum reserves** were set to a fixed proportion of the total demand.

* **Contingencies** were set to include all N-1 transmission line contingencies that do not generate islands or isolated buses. More specifically, there is one contingency for each transmission line, as long as that transmission line is not a bridge in the network graph.

For each MATPOWER test case, UC.jl provides two variations (`2017-02-01` and `2017-08-01`) corresponding respectively to a winter and to a summer test case.

### 2.1 MATPOWER/UW-PSTCA

A variety of smaller IEEE test cases, [compiled by University of Wisconsin](http://labs.ece.uw.edu/pstca/), corresponding mostly to small portions of the American Electric Power System in the 1960s.

| Name | Buses | Generators | Lines | Contingencies | References |
|------|-------|------------|-------|---------------|--------|
| `matpower/case14/2017-02-01` | 14 | 5 | 20 | 19 | [ZiMSTh11], [PSTCA]
| `matpower/case14/2017-08-01` | 14 | 5 | 20 | 19 | [ZiMSTh11], [PSTCA]
| `matpower/case30/2017-02-01` | 30 | 6 | 41 | 38 | [ZiMSTh11], [PSTCA]
| `matpower/case30/2017-08-01` | 30 | 6 | 41 | 38 | [ZiMSTh11], [PSTCA]
| `matpower/case57/2017-02-01` | 57 | 7 | 80 | 79 | [ZiMSTh11], [PSTCA]
| `matpower/case57/2017-08-01` | 57 | 7 | 80 | 79 | [ZiMSTh11], [PSTCA]
| `matpower/case118/2017-02-01` | 118 | 54 | 186 | 177 | [ZiMSTh11], [PSTCA]
| `matpower/case118/2017-08-01` | 118 | 54 | 186 | 177 | [ZiMSTh11], [PSTCA]
| `matpower/case300/2017-02-01` | 300 | 69 | 411 | 320 | [ZiMSTh11], [PSTCA]
| `matpower/case300/2017-08-01` | 300 | 69 | 411 | 320 | [ZiMSTh11], [PSTCA]


### 2.2 MATPOWER/Polish

Test cases based on the Polish 400, 220 and 110 kV networks, originally provided by **Roman Korab** (Politechnika Śląska) and corrected by the MATPOWER team.

| Name | Buses | Generators | Lines | Contingencies | References |
|------|-------|------------|-------|---------------|--------|
| `matpower/case2383wp/2017-02-01` | 2383 | 323 | 2896 | 2240 | [ZiMSTh11]
| `matpower/case2383wp/2017-08-01` | 2383 | 323 | 2896 | 2240 | [ZiMSTh11]
| `matpower/case2736sp/2017-02-01` | 2736 | 289 | 3504 | 3159 | [ZiMSTh11]
| `matpower/case2736sp/2017-08-01` | 2736 | 289 | 3504 | 3159 | [ZiMSTh11]
| `matpower/case2737sop/2017-02-01` | 2737 | 267 | 3506 | 3161 | [ZiMSTh11]
| `matpower/case2737sop/2017-08-01` | 2737 | 267 | 3506 | 3161 | [ZiMSTh11]
| `matpower/case2746wop/2017-02-01` | 2746 | 443 | 3514 | 3155 | [ZiMSTh11]
| `matpower/case2746wop/2017-08-01` | 2746 | 443 | 3514 | 3155 | [ZiMSTh11]
| `matpower/case2746wp/2017-02-01` | 2746 | 457 | 3514 | 3156 | [ZiMSTh11]
| `matpower/case2746wp/2017-08-01` | 2746 | 457 | 3514 | 3156 | [ZiMSTh11]
| `matpower/case3012wp/2017-02-01` | 3012 | 496 | 3572 | 2854 | [ZiMSTh11]
| `matpower/case3012wp/2017-08-01` | 3012 | 496 | 3572 | 2854 | [ZiMSTh11]
| `matpower/case3120sp/2017-02-01` | 3120 | 483 | 3693 | 2950 | [ZiMSTh11]
| `matpower/case3120sp/2017-08-01` | 3120 | 483 | 3693 | 2950 | [ZiMSTh11]
| `matpower/case3375wp/2017-02-01` | 3374 | 590 | 4161 | 3245 | [ZiMSTh11]
| `matpower/case3375wp/2017-08-01` | 3374 | 590 | 4161 | 3245 | [ZiMSTh11]

### 2.3 MATPOWER/PEGASE

Test cases from the [Pan European Grid Advanced Simulation and State Estimation (PEGASE) project](https://www.fp7-pegase.com/), describing part of the European high voltage transmission network.

| Name | Buses | Generators | Lines | Contingencies | References |
|------|-------|------------|-------|---------------|--------|
| `matpower/case89pegase/2017-02-01` | 89 | 12 | 210 | 192 | [JoFlMa16], [FlPaCa13], [ZiMSTh11]
| `matpower/case89pegase/2017-08-01` | 89 | 12 | 210 | 192 | [JoFlMa16], [FlPaCa13], [ZiMSTh11]
| `matpower/case2869pegase/2017-02-01` | 2869 | 510 | 4582 | 3579 | [JoFlMa16], [FlPaCa13], [ZiMSTh11]
| `matpower/case2869pegase/2017-08-01` | 2869 | 510 | 4582 | 3579 | [JoFlMa16], [FlPaCa13], [ZiMSTh11]
| `matpower/case9241pegase/2017-02-01` | 9241 | 1445 | 16049 | 13932 | [JoFlMa16], [FlPaCa13], [ZiMSTh11]
| `matpower/case9241pegase/2017-08-01` | 9241 | 1445 | 16049 | 13932 | [JoFlMa16], [FlPaCa13], [ZiMSTh11]
| `matpower/case1354pegase/2017-02-01` | 1354 | 260 | 1991 | 1288 | [JoFlMa16], [FlPaCa13], [ZiMSTh11]
| `matpower/case1354pegase/2017-08-01` | 1354 | 260 | 1991 | 1288 | [JoFlMa16], [FlPaCa13], [ZiMSTh11]
| `matpower/case13659pegase/2017-02-01` | 13659 | 4092 | 20467 | 13932 | [JoFlMa16], [FlPaCa13], [ZiMSTh11]
| `matpower/case13659pegase/2017-08-01` | 13659 | 4092 | 20467 | 13932 | [JoFlMa16], [FlPaCa13], [ZiMSTh11]

## 3. References

* [UCJL] Alinson S. Xavier, Feng Qiu, "UnitCommitment.jl: A Julia/JuMP Optimization Package for Security-Constrained Unit Commitment". Zenodo (2020). [DOI: 10.5281/zenodo.4269874](https://doi.org/10.5281/zenodo.4269874).

* [KnOsWa18] Bernard Knueven, James Ostrowski and Jean-Paul Watson. "On mixed integer programming formulations for the unit commitment problem." Pre-print available at http://www.optimization-online.org/DB_HTML/2018/11/6930.pdf (2018).

* [KrHiOn12] Eric Krall, Michael Higgins and Richard P. O’Neill. "RTO unit commitment test system." Federal Energy Regulatory Commission. Available: http://ferc.gov/legal/staff-reports/rto-COMMITMENT-TEST.pdf (2012).

* [BaBlEh19] Clayton Barrows, Aaron Bloom, Ali Ehlen, Jussi Ikaheimo, Jennie Jorgenson, Dheepak Krishnamurthy, Jessica Lau et al. "The IEEE Reliability Test System: A Proposed 2019 Update." IEEE Transactions on Power Systems (2019).

* [JoFlMa16] C. Josz, S. Fliscounakis, J. Maeght, and P. Panciatici, "AC Power Flow
Data in MATPOWER and QCQP Format: iTesla, RTE Snapshots, and PEGASE"
https://arxiv.org/abs/1603.01533

* [FlPaCa13] S. Fliscounakis, P. Panciatici, F. Capitanescu, and L. Wehenkel,
"Contingency ranking with respect to overloads in very large power
systems taking into account uncertainty, preventive and corrective
actions", Power Systems, IEEE Trans. on, (28)4:4909-4917, 2013.
https://doi.org/10.1109/TPWRS.2013.2251015

* [ZiMSTh11] D. Zimmerman, C. E. Murillo-Sandnchez and R. J. Thomas, "Matpower:  Steady-state  operations,  planning,  and  analysis  tools  forpower systems research and education", IEEE Transactions on PowerSystems, vol. 26, no. 1, pp. 12 –19, Feb. 2011.

* [PSTCA] University of Washington, Dept. of Electrical Engineering, "Power Systems Test Case Archive", Published online at http://www.ee.washington.edu/research/pstca/, 1999.