```{sectnum}
---
start: 3
depth: 2
suffix: .
---
```

Instances
=========

UnitCommitment.jl provides a large collection of benchmark instances collected
from the literature and converted to a [common data format](format.md). In some cases, as indicated below, the original instances have been extended, with realistic parameters, using data-driven methods. 
If you use these instances in your research, we request that you cite UnitCommitment.jl, as well as the original sources.

Raw instances files are [available at our GitHub repository](https://github.com/ANL-CEEESA/UnitCommitment.jl/tree/dev/instances). Benchmark instances can also be loaded with
`UnitCommitment.read_benchmark(name)`, as explained in the [usage section](usage.md).


MATPOWER
--------

[MATPOWER](https://github.com/MATPOWER/matpower) is an open-source package for solving power flow problems in MATLAB and Octave. It contains a number of power flow test cases, which have been widely used in the power systems literature.

Because most MATPOWER test cases were originally designed for power flow studies, they lack a number of important unit commitment parameters, such as time-varying loads, production cost curves, ramp limits, reserves and initial conditions. The test cases included in UnitCommitment.jl are extended versions of the original MATPOWER test cases, modified as following:

* **Production cost** curves were generated using a data-driven approach, based on publicly available data. More specifically, machine learning models were trained to predict typical production cost curves, for each day of the year, based on a generator's maximum and minimum power output.

* **Load profiles** were generated using a similar data-driven approach.

* **Ramp-up, ramp-down, startup and shutdown rates** were set to a fixed proportion of the generator's maximum output.

* **Minimum reserves** were set to a fixed proportion of the total demand.

* **Contingencies** were set to include all N-1 transmission line contingencies that do not generate islands or isolated buses. More specifically, there is one contingency for each transmission line, as long as that transmission line is not a bridge in the network graph.

For each MATPOWER test case, UC.jl provides two variations (`2017-02-01` and `2017-08-01`) corresponding respectively to a winter and to a summer test case.

### MATPOWER/UW-PSTCA

A variety of smaller IEEE test cases, [compiled by University of Washington](http://labs.ece.uw.edu/pstca/), corresponding mostly to small portions of the American Electric Power System in the 1960s.

| Name | Buses | Generators | Lines | Contingencies | References |
|------|-------|------------|-------|---------------|--------|
| `matpower/case14/2017-02-01` | 14 | 5 | 20 | 19 | [MTPWR, PSTCA]
| `matpower/case14/2017-08-01` | 14 | 5 | 20 | 19 | [MTPWR, PSTCA]
| `matpower/case30/2017-02-01` | 30 | 6 | 41 | 38 | [MTPWR, PSTCA]
| `matpower/case30/2017-08-01` | 30 | 6 | 41 | 38 | [MTPWR, PSTCA]
| `matpower/case57/2017-02-01` | 57 | 7 | 80 | 79 | [MTPWR, PSTCA]
| `matpower/case57/2017-08-01` | 57 | 7 | 80 | 79 | [MTPWR, PSTCA]
| `matpower/case118/2017-02-01` | 118 | 54 | 186 | 177 | [MTPWR, PSTCA]
| `matpower/case118/2017-08-01` | 118 | 54 | 186 | 177 | [MTPWR, PSTCA]
| `matpower/case300/2017-02-01` | 300 | 69 | 411 | 320 | [MTPWR, PSTCA]
| `matpower/case300/2017-08-01` | 300 | 69 | 411 | 320 | [MTPWR, PSTCA]


### MATPOWER/Polish

Test cases based on the Polish 400, 220 and 110 kV networks, originally provided by **Roman Korab** (Politechnika Śląska) and corrected by the MATPOWER team.

| Name | Buses | Generators | Lines | Contingencies | References |
|------|-------|------------|-------|---------------|--------|
| `matpower/case2383wp/2017-02-01` | 2383 | 323 | 2896 | 2240 | [MTPWR]
| `matpower/case2383wp/2017-08-01` | 2383 | 323 | 2896 | 2240 | [MTPWR]
| `matpower/case2736sp/2017-02-01` | 2736 | 289 | 3504 | 3159 | [MTPWR]
| `matpower/case2736sp/2017-08-01` | 2736 | 289 | 3504 | 3159 | [MTPWR]
| `matpower/case2737sop/2017-02-01` | 2737 | 267 | 3506 | 3161 | [MTPWR]
| `matpower/case2737sop/2017-08-01` | 2737 | 267 | 3506 | 3161 | [MTPWR]
| `matpower/case2746wop/2017-02-01` | 2746 | 443 | 3514 | 3155 | [MTPWR]
| `matpower/case2746wop/2017-08-01` | 2746 | 443 | 3514 | 3155 | [MTPWR]
| `matpower/case2746wp/2017-02-01` | 2746 | 457 | 3514 | 3156 | [MTPWR]
| `matpower/case2746wp/2017-08-01` | 2746 | 457 | 3514 | 3156 | [MTPWR]
| `matpower/case3012wp/2017-02-01` | 3012 | 496 | 3572 | 2854 | [MTPWR]
| `matpower/case3012wp/2017-08-01` | 3012 | 496 | 3572 | 2854 | [MTPWR]
| `matpower/case3120sp/2017-02-01` | 3120 | 483 | 3693 | 2950 | [MTPWR]
| `matpower/case3120sp/2017-08-01` | 3120 | 483 | 3693 | 2950 | [MTPWR]
| `matpower/case3375wp/2017-02-01` | 3374 | 590 | 4161 | 3245 | [MTPWR]
| `matpower/case3375wp/2017-08-01` | 3374 | 590 | 4161 | 3245 | [MTPWR]

### MATPOWER/PEGASE

Test cases from the [Pan European Grid Advanced Simulation and State Estimation (PEGASE) project](https://cordis.europa.eu/project/id/211407), describing part of the European high voltage transmission network.

| Name | Buses | Generators | Lines | Contingencies | References |
|------|-------|------------|-------|---------------|--------|
| `matpower/case89pegase/2017-02-01` | 89 | 12 | 210 | 192 | [JoFlMa16, FlPaCa13, MTPWR]
| `matpower/case89pegase/2017-08-01` | 89 | 12 | 210 | 192 | [JoFlMa16, FlPaCa13, MTPWR]
| `matpower/case1354pegase/2017-02-01` | 1354 | 260 | 1991 | 1288 | [JoFlMa16, FlPaCa13, MTPWR]
| `matpower/case1354pegase/2017-08-01` | 1354 | 260 | 1991 | 1288 | [JoFlMa16, FlPaCa13, MTPWR]
| `matpower/case2869pegase/2017-02-01` | 2869 | 510 | 4582 | 3579 | [JoFlMa16, FlPaCa13, MTPWR]
| `matpower/case2869pegase/2017-08-01` | 2869 | 510 | 4582 | 3579 | [JoFlMa16, FlPaCa13, MTPWR]
| `matpower/case9241pegase/2017-02-01` | 9241 | 1445 | 16049 | 13932 | [JoFlMa16, FlPaCa13, MTPWR]
| `matpower/case9241pegase/2017-08-01` | 9241 | 1445 | 16049 | 13932 | [JoFlMa16, FlPaCa13, MTPWR]
| `matpower/case13659pegase/2017-02-01` | 13659 | 4092 | 20467 | 13932 | [JoFlMa16, FlPaCa13, MTPWR]
| `matpower/case13659pegase/2017-08-01` | 13659 | 4092 | 20467 | 13932 | [JoFlMa16, FlPaCa13, MTPWR]

### MATPOWER/RTE

Test cases from the R&D Division at [Reseau de Transport d'Electricite](https://www.rte-france.com) representing the size and complexity of the French very high voltage transmission network.

| Name | Buses | Generators | Lines | Contingencies | References |
|------|-------|------------|-------|---------------|--------|
| `matpower/case1888rte/2017-02-01` | 1888 | 296 | 2531 | 1484 | [MTPWR, JoFlMa16]
| `matpower/case1888rte/2017-08-01` | 1888 | 296 | 2531 | 1484 | [MTPWR, JoFlMa16]
| `matpower/case1951rte/2017-02-01` | 1951 | 390 | 2596 | 1497 | [MTPWR, JoFlMa16]
| `matpower/case1951rte/2017-08-01` | 1951 | 390 | 2596 | 1497 | [MTPWR, JoFlMa16]
| `matpower/case2848rte/2017-02-01` | 2848 | 544 | 3776 | 2242 | [MTPWR, JoFlMa16]
| `matpower/case2848rte/2017-08-01` | 2848 | 544 | 3776 | 2242 | [MTPWR, JoFlMa16]
| `matpower/case2868rte/2017-02-01` | 2868 | 596 | 3808 | 2260 | [MTPWR, JoFlMa16]
| `matpower/case2868rte/2017-08-01` | 2868 | 596 | 3808 | 2260 | [MTPWR, JoFlMa16]
| `matpower/case6468rte/2017-02-01` | 6468 | 1262 | 9000 | 6094 | [MTPWR, JoFlMa16]
| `matpower/case6468rte/2017-08-01` | 6468 | 1262 | 9000 | 6094 | [MTPWR, JoFlMa16]
| `matpower/case6470rte/2017-02-01` | 6470 | 1306 | 9005 | 6085 | [MTPWR, JoFlMa16]
| `matpower/case6470rte/2017-08-01` | 6470 | 1306 | 9005 | 6085 | [MTPWR, JoFlMa16]
| `matpower/case6495rte/2017-02-01` | 6495 | 1352 | 9019 | 6060 | [MTPWR, JoFlMa16]
| `matpower/case6495rte/2017-08-01` | 6495 | 1352 | 9019 | 6060 | [MTPWR, JoFlMa16]
| `matpower/case6515rte/2017-02-01` | 6515 | 1368 | 9037 | 6063 | [MTPWR, JoFlMa16]
| `matpower/case6515rte/2017-08-01` | 6515 | 1368 | 9037 | 6063 | [MTPWR, JoFlMa16]


PGLIB-UC Instances
------------------

[PGLIB-UC](https://github.com/power-grid-lib/pglib-uc) is a benchmark library curated and maintained by the [IEEE PES Task Force on Benchmarks for Validation of Emerging Power System Algorithms](https://power-grid-lib.github.io/). These test cases have been used in [KnOsWa20].

### PGLIB-UC/California

Test cases based on publicly available data from the California ISO. For more details, see [PGLIB-UC case file overview](https://github.com/power-grid-lib/pglib-uc).

| Name | Buses | Generators | Lines | Contingencies | References |
|------|-------|------------|-------|---------------|--------|
| `pglib-uc/ca/2014-09-01_reserves_0` | 1 | 610 | 0 | 0 | [KnOsWa20]
| `pglib-uc/ca/2014-09-01_reserves_1` | 1 | 610 | 0 | 0 | [KnOsWa20]
| `pglib-uc/ca/2014-09-01_reserves_3` | 1 | 610 | 0 | 0 | [KnOsWa20]
| `pglib-uc/ca/2014-09-01_reserves_5` | 1 | 610 | 0 | 0 | [KnOsWa20]
| `pglib-uc/ca/2014-12-01_reserves_0` | 1 | 610 | 0 | 0 | [KnOsWa20]
| `pglib-uc/ca/2014-12-01_reserves_1` | 1 | 610 | 0 | 0 | [KnOsWa20]
| `pglib-uc/ca/2014-12-01_reserves_3` | 1 | 610 | 0 | 0 | [KnOsWa20]
| `pglib-uc/ca/2014-12-01_reserves_5` | 1 | 610 | 0 | 0 | [KnOsWa20]
| `pglib-uc/ca/2015-03-01_reserves_0` | 1 | 610 | 0 | 0 | [KnOsWa20]
| `pglib-uc/ca/2015-03-01_reserves_1` | 1 | 610 | 0 | 0 | [KnOsWa20]
| `pglib-uc/ca/2015-03-01_reserves_3` | 1 | 610 | 0 | 0 | [KnOsWa20]
| `pglib-uc/ca/2015-03-01_reserves_5` | 1 | 610 | 0 | 0 | [KnOsWa20]
| `pglib-uc/ca/2015-06-01_reserves_0` | 1 | 610 | 0 | 0 | [KnOsWa20]
| `pglib-uc/ca/2015-06-01_reserves_1` | 1 | 610 | 0 | 0 | [KnOsWa20]
| `pglib-uc/ca/2015-06-01_reserves_3` | 1 | 610 | 0 | 0 | [KnOsWa20]
| `pglib-uc/ca/2015-06-01_reserves_5` | 1 | 610 | 0 | 0 | [KnOsWa20]
| `pglib-uc/ca/Scenario400_reserves_0` | 1 | 611 | 0 | 0 | [KnOsWa20]
| `pglib-uc/ca/Scenario400_reserves_1` | 1 | 611 | 0 | 0 | [KnOsWa20]
| `pglib-uc/ca/Scenario400_reserves_3` | 1 | 611 | 0 | 0 | [KnOsWa20]
| `pglib-uc/ca/Scenario400_reserves_5` | 1 | 611 | 0 | 0 | [KnOsWa20]


### PGLIB-UC/FERC

Test cases based on a publicly available [unit commitment test case produced by the Federal Energy Regulatory Commission](https://www.ferc.gov/industries-data/electric/power-sales-and-markets/increasing-efficiency-through-improved-software-1). For more details, see [PGLIB-UC case file overview](https://github.com/power-grid-lib/pglib-uc).

| Name | Buses | Generators | Lines | Contingencies | References |
|------|-------|------------|-------|---------------|--------|
| `pglib-uc/ferc/2015-01-01_hw` | 1 | 935 | 0 | 0 | [KnOsWa20, KrHiOn12]
| `pglib-uc/ferc/2015-01-01_lw` | 1 | 935 | 0 | 0 | [KnOsWa20, KrHiOn12]
| `pglib-uc/ferc/2015-02-01_hw` | 1 | 935 | 0 | 0 | [KnOsWa20, KrHiOn12]
| `pglib-uc/ferc/2015-02-01_lw` | 1 | 935 | 0 | 0 | [KnOsWa20, KrHiOn12]
| `pglib-uc/ferc/2015-03-01_hw` | 1 | 935 | 0 | 0 | [KnOsWa20, KrHiOn12]
| `pglib-uc/ferc/2015-03-01_lw` | 1 | 935 | 0 | 0 | [KnOsWa20, KrHiOn12]
| `pglib-uc/ferc/2015-04-01_hw` | 1 | 979 | 0 | 0 | [KnOsWa20, KrHiOn12]
| `pglib-uc/ferc/2015-04-01_lw` | 1 | 979 | 0 | 0 | [KnOsWa20, KrHiOn12]
| `pglib-uc/ferc/2015-05-01_hw` | 1 | 979 | 0 | 0 | [KnOsWa20, KrHiOn12]
| `pglib-uc/ferc/2015-05-01_lw` | 1 | 979 | 0 | 0 | [KnOsWa20, KrHiOn12]
| `pglib-uc/ferc/2015-06-01_hw` | 1 | 979 | 0 | 0 | [KnOsWa20, KrHiOn12]
| `pglib-uc/ferc/2015-06-01_lw` | 1 | 979 | 0 | 0 | [KnOsWa20, KrHiOn12]
| `pglib-uc/ferc/2015-07-01_hw` | 1 | 979 | 0 | 0 | [KnOsWa20, KrHiOn12]
| `pglib-uc/ferc/2015-07-01_lw` | 1 | 979 | 0 | 0 | [KnOsWa20, KrHiOn12]
| `pglib-uc/ferc/2015-08-01_hw` | 1 | 979 | 0 | 0 | [KnOsWa20, KrHiOn12]
| `pglib-uc/ferc/2015-08-01_lw` | 1 | 979 | 0 | 0 | [KnOsWa20, KrHiOn12]
| `pglib-uc/ferc/2015-09-01_hw` | 1 | 979 | 0 | 0 | [KnOsWa20, KrHiOn12]
| `pglib-uc/ferc/2015-09-01_lw` | 1 | 979 | 0 | 0 | [KnOsWa20, KrHiOn12]
| `pglib-uc/ferc/2015-10-01_hw` | 1 | 935 | 0 | 0 | [KnOsWa20, KrHiOn12]
| `pglib-uc/ferc/2015-10-01_lw` | 1 | 935 | 0 | 0 | [KnOsWa20, KrHiOn12]
| `pglib-uc/ferc/2015-11-02_hw` | 1 | 935 | 0 | 0 | [KnOsWa20, KrHiOn12]
| `pglib-uc/ferc/2015-11-02_lw` | 1 | 935 | 0 | 0 | [KnOsWa20, KrHiOn12]
| `pglib-uc/ferc/2015-12-01_hw` | 1 | 935 | 0 | 0 | [KnOsWa20, KrHiOn12]
| `pglib-uc/ferc/2015-12-01_lw` | 1 | 935 | 0 | 0 | [KnOsWa20, KrHiOn12]


### PGLIB-UC/RTS-GMLC

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


OR-LIB/UC
---------

[OR-LIB](http://people.brunel.ac.uk/~mastjjb/jeb/info.html) is a collection of test data sets for a variety of operations research problems, including unit commitment. The UC instances in OR-LIB are synthetic instances generated by a [random problem generator](http://groups.di.unipi.it/optimize/Data/UC.html) developed by the [Operations Research Group at University of Pisa](http://groups.di.unipi.it/optimize/). These test cases have been used in [FrGe06] and many other publications.

| Name | Hours | Buses | Generators | Lines | Contingencies | References |
|------|-------|-------|------------|-------|---------------|------------|
| `or-lib/10_0_1_w` | 24 | 1 | 10 | 0 | 0 | [ORLIB, FrGe06]
| `or-lib/10_0_2_w` | 24 | 1 | 10 | 0 | 0 | [ORLIB, FrGe06]
| `or-lib/10_0_3_w` | 24 | 1 | 10 | 0 | 0 | [ORLIB, FrGe06]
| `or-lib/10_0_4_w` | 24 | 1 | 10 | 0 | 0 | [ORLIB, FrGe06]
| `or-lib/10_0_5_w` | 24 | 1 | 10 | 0 | 0 | [ORLIB, FrGe06]
| `or-lib/20_0_1_w` | 24 | 1 | 20 | 0 | 0 | [ORLIB, FrGe06]
| `or-lib/20_0_2_w` | 24 | 1 | 20 | 0 | 0 | [ORLIB, FrGe06]
| `or-lib/20_0_3_w` | 24 | 1 | 20 | 0 | 0 | [ORLIB, FrGe06]
| `or-lib/20_0_4_w` | 24 | 1 | 20 | 0 | 0 | [ORLIB, FrGe06]
| `or-lib/20_0_5_w` | 24 | 1 | 20 | 0 | 0 | [ORLIB, FrGe06]
| `or-lib/50_0_1_w` | 24 | 1 | 50 | 0 | 0 | [ORLIB, FrGe06]
| `or-lib/50_0_2_w` | 24 | 1 | 50 | 0 | 0 | [ORLIB, FrGe06]
| `or-lib/50_0_3_w` | 24 | 1 | 50 | 0 | 0 | [ORLIB, FrGe06]
| `or-lib/50_0_4_w` | 24 | 1 | 50 | 0 | 0 | [ORLIB, FrGe06]
| `or-lib/50_0_5_w` | 24 | 1 | 50 | 0 | 0 | [ORLIB, FrGe06]
| `or-lib/75_0_1_w` | 24 | 1 | 75 | 0 | 0 | [ORLIB, FrGe06]
| `or-lib/75_0_2_w` | 24 | 1 | 75 | 0 | 0 | [ORLIB, FrGe06]
| `or-lib/75_0_3_w` | 24 | 1 | 75 | 0 | 0 | [ORLIB, FrGe06]
| `or-lib/75_0_4_w` | 24 | 1 | 75 | 0 | 0 | [ORLIB, FrGe06]
| `or-lib/75_0_5_w` | 24 | 1 | 75 | 0 | 0 | [ORLIB, FrGe06]
| `or-lib/100_0_1_w` | 24 | 1 | 100 | 0 | 0 | [ORLIB, FrGe06]
| `or-lib/100_0_2_w` | 24 | 1 | 100 | 0 | 0 | [ORLIB, FrGe06]
| `or-lib/100_0_3_w` | 24 | 1 | 100 | 0 | 0 | [ORLIB, FrGe06]
| `or-lib/100_0_4_w` | 24 | 1 | 100 | 0 | 0 | [ORLIB, FrGe06]
| `or-lib/100_0_5_w` | 24 | 1 | 100 | 0 | 0 | [ORLIB, FrGe06]
| `or-lib/150_0_1_w` | 24 | 1 | 150 | 0 | 0 | [ORLIB, FrGe06]
| `or-lib/150_0_2_w` | 24 | 1 | 150 | 0 | 0 | [ORLIB, FrGe06]
| `or-lib/150_0_3_w` | 24 | 1 | 150 | 0 | 0 | [ORLIB, FrGe06]
| `or-lib/150_0_4_w` | 24 | 1 | 150 | 0 | 0 | [ORLIB, FrGe06]
| `or-lib/150_0_5_w` | 24 | 1 | 150 | 0 | 0 | [ORLIB, FrGe06]
| `or-lib/200_0_10_w` | 24 | 1 | 200 | 0 | 0 | [ORLIB, FrGe06]
| `or-lib/200_0_11_w` | 24 | 1 | 200 | 0 | 0 | [ORLIB, FrGe06]
| `or-lib/200_0_12_w` | 24 | 1 | 200 | 0 | 0 | [ORLIB, FrGe06]
| `or-lib/200_0_1_w` | 24 | 1 | 200 | 0 | 0 | [ORLIB, FrGe06]
| `or-lib/200_0_2_w` | 24 | 1 | 200 | 0 | 0 | [ORLIB, FrGe06]
| `or-lib/200_0_3_w` | 24 | 1 | 200 | 0 | 0 | [ORLIB, FrGe06]
| `or-lib/200_0_4_w` | 24 | 1 | 200 | 0 | 0 | [ORLIB, FrGe06]
| `or-lib/200_0_5_w` | 24 | 1 | 200 | 0 | 0 | [ORLIB, FrGe06]
| `or-lib/200_0_6_w` | 24 | 1 | 200 | 0 | 0 | [ORLIB, FrGe06]
| `or-lib/200_0_7_w` | 24 | 1 | 200 | 0 | 0 | [ORLIB, FrGe06]
| `or-lib/200_0_8_w` | 24 | 1 | 200 | 0 | 0 | [ORLIB, FrGe06]
| `or-lib/200_0_9_w` | 24 | 1 | 200 | 0 | 0 | [ORLIB, FrGe06]


Tejada19
--------

 Test cases used in [TeLuSa19]. These instances are similar to OR-LIB/UC, in the sense that they use the same random problem generator, but are much larger.

| Name | Hours | Buses | Generators | Lines | Contingencies | References |
|------|-------|-------|------------|-------|---------------|------------|
| `tejada19/UC_24h_214g` | 24 | 1 | 214 | 0 | 0 | [TeLuSa19]
| `tejada19/UC_24h_250g` | 24 | 1 | 250 | 0 | 0 | [TeLuSa19]
| `tejada19/UC_24h_290g` | 24 | 1 | 290 | 0 | 0 | [TeLuSa19]
| `tejada19/UC_24h_480g` | 24 | 1 | 480 | 0 | 0 | [TeLuSa19]
| `tejada19/UC_24h_505g` | 24 | 1 | 505 | 0 | 0 | [TeLuSa19]
| `tejada19/UC_24h_623g` | 24 | 1 | 623 | 0 | 0 | [TeLuSa19]
| `tejada19/UC_24h_647g` | 24 | 1 | 647 | 0 | 0 | [TeLuSa19]
| `tejada19/UC_24h_836g` | 24 | 1 | 836 | 0 | 0 | [TeLuSa19]
| `tejada19/UC_24h_850g` | 24 | 1 | 850 | 0 | 0 | [TeLuSa19]
| `tejada19/UC_24h_918g` | 24 | 1 | 918 | 0 | 0 | [TeLuSa19]
| `tejada19/UC_24h_931g` | 24 | 1 | 931 | 0 | 0 | [TeLuSa19]
| `tejada19/UC_24h_940g` | 24 | 1 | 940 | 0 | 0 | [TeLuSa19]
| `tejada19/UC_24h_957g` | 24 | 1 | 957 | 0 | 0 | [TeLuSa19]
| `tejada19/UC_24h_959g` | 24 | 1 | 959 | 0 | 0 | [TeLuSa19]
| `tejada19/UC_24h_1069g` | 24 | 1 | 1069 | 0 | 0 | [TeLuSa19]
| `tejada19/UC_24h_1130g` | 24 | 1 | 1130 | 0 | 0 | [TeLuSa19]
| `tejada19/UC_24h_1376g` | 24 | 1 | 1376 | 0 | 0 | [TeLuSa19]
| `tejada19/UC_24h_1393g` | 24 | 1 | 1393 | 0 | 0 | [TeLuSa19]
| `tejada19/UC_24h_1577g` | 24 | 1 | 1577 | 0 | 0 | [TeLuSa19]
| `tejada19/UC_24h_1615g` | 24 | 1 | 1615 | 0 | 0 | [TeLuSa19]
| `tejada19/UC_24h_1632g` | 24 | 1 | 1632 | 0 | 0 | [TeLuSa19]
| `tejada19/UC_24h_1768g` | 24 | 1 | 1768 | 0 | 0 | [TeLuSa19]
| `tejada19/UC_24h_1804g` | 24 | 1 | 1804 | 0 | 0 | [TeLuSa19]
| `tejada19/UC_24h_1820g` | 24 | 1 | 1820 | 0 | 0 | [TeLuSa19]
| `tejada19/UC_24h_1823g` | 24 | 1 | 1823 | 0 | 0 | [TeLuSa19]
| `tejada19/UC_24h_1888g` | 24 | 1 | 1888 | 0 | 0 | [TeLuSa19]
| `tejada19/UC_168h_36g` | 168 | 1 | 36 | 0 | 0 | [TeLuSa19]
| `tejada19/UC_168h_38g` | 168 | 1 | 38 | 0 | 0 | [TeLuSa19]
| `tejada19/UC_168h_40g` | 168 | 1 | 40 | 0 | 0 | [TeLuSa19]
| `tejada19/UC_168h_53g` | 168 | 1 | 53 | 0 | 0 | [TeLuSa19]
| `tejada19/UC_168h_58g` | 168 | 1 | 58 | 0 | 0 | [TeLuSa19]
| `tejada19/UC_168h_59g` | 168 | 1 | 59 | 0 | 0 | [TeLuSa19]
| `tejada19/UC_168h_72g` | 168 | 1 | 72 | 0 | 0 | [TeLuSa19]
| `tejada19/UC_168h_84g` | 168 | 1 | 84 | 0 | 0 | [TeLuSa19]
| `tejada19/UC_168h_86g` | 168 | 1 | 86 | 0 | 0 | [TeLuSa19]
| `tejada19/UC_168h_88g` | 168 | 1 | 88 | 0 | 0 | [TeLuSa19]
| `tejada19/UC_168h_93g` | 168 | 1 | 93 | 0 | 0 | [TeLuSa19]
| `tejada19/UC_168h_105g` | 168 | 1 | 105 | 0 | 0 | [TeLuSa19]
| `tejada19/UC_168h_110g` | 168 | 1 | 110 | 0 | 0 | [TeLuSa19]
| `tejada19/UC_168h_125g` | 168 | 1 | 125 | 0 | 0 | [TeLuSa19]
| `tejada19/UC_168h_130g` | 168 | 1 | 130 | 0 | 0 | [TeLuSa19]
| `tejada19/UC_168h_131g` | 168 | 1 | 131 | 0 | 0 | [TeLuSa19]
| `tejada19/UC_168h_140g` | 168 | 1 | 140 | 0 | 0 | [TeLuSa19]
| `tejada19/UC_168h_165g` | 168 | 1 | 165 | 0 | 0 | [TeLuSa19]
| `tejada19/UC_168h_175g` | 168 | 1 | 175 | 0 | 0 | [TeLuSa19]
| `tejada19/UC_168h_179g` | 168 | 1 | 179 | 0 | 0 | [TeLuSa19]
| `tejada19/UC_168h_188g` | 168 | 1 | 188 | 0 | 0 | [TeLuSa19]
| `tejada19/UC_168h_192g` | 168 | 1 | 192 | 0 | 0 | [TeLuSa19]
| `tejada19/UC_168h_199g` | 168 | 1 | 199 | 0 | 0 | [TeLuSa19]


References
----------

* [UCJL] **Alinson S. Xavier, Aleksandr M. Kazachkov, Feng Qiu.** "UnitCommitment.jl: A Julia/JuMP Optimization Package for Security-Constrained Unit Commitment". Zenodo (2020). [DOI: 10.5281/zenodo.4269874](https://doi.org/10.5281/zenodo.4269874)

* [KnOsWa20] **Bernard Knueven, James Ostrowski and Jean-Paul Watson.** "On Mixed-Integer Programming Formulations for the Unit Commitment Problem". INFORMS Journal on Computing (2020). [DOI: 10.1287/ijoc.2019.0944](https://doi.org/10.1287/ijoc.2019.0944)

* [KrHiOn12] **Eric Krall, Michael Higgins and Richard P. O’Neill.** "RTO unit commitment test system." Federal Energy Regulatory Commission. Available at: <https://www.ferc.gov/industries-data/electric/power-sales-and-markets/increasing-efficiency-through-improved-software-1> (Accessed: Nov 14, 2020)

* [BaBlEh19] **Clayton Barrows, Aaron Bloom, Ali Ehlen, Jussi Ikaheimo, Jennie Jorgenson, Dheepak Krishnamurthy, Jessica Lau et al.** "The IEEE Reliability Test System: A Proposed 2019 Update." IEEE Transactions on Power Systems (2019). [DOI: 10.1109/TPWRS.2019.2925557](https://doi.org/10.1109/TPWRS.2019.2925557)

* [JoFlMa16] **C. Josz, S. Fliscounakis, J. Maeght, and P. Panciatici.** "AC Power Flow
Data in MATPOWER and QCQP Format: iTesla, RTE Snapshots, and PEGASE". [ArXiv (2016)](https://arxiv.org/abs/1603.01533).

* [FlPaCa13] **S. Fliscounakis, P. Panciatici, F. Capitanescu, and L. Wehenkel.**
"Contingency ranking with respect to overloads in very large power
systems taking into account uncertainty, preventive and corrective
actions", Power Systems, IEEE Trans. on, (28)4:4909-4917, 2013.
[DOI: 10.1109/TPWRS.2013.2251015](https://doi.org/10.1109/TPWRS.2013.2251015)

* [MTPWR] **D. Zimmerman, C. E. Murillo-Sandnchez and R. J. Thomas.** "Matpower:  Steady-state  operations,  planning,  and  analysis  tools  forpower systems research and education", IEEE Transactions on PowerSystems, vol. 26, no. 1, pp. 12 –19, Feb. 2011. [DOI: 10.1109/TPWRS.2010.2051168](https://doi.org/10.1109/TPWRS.2010.2051168)

* [PSTCA] **University of Washington, Dept. of Electrical Engineering.** "Power Systems Test Case Archive". Available at: <http://www.ee.washington.edu/research/pstca/> (Accessed: Nov 14, 2020)

* [ORLIB] **J.E.Beasley.** "OR-Library: distributing test problems by electronic mail", Journal of the Operational Research Society 41(11) (1990). [DOI: 10.2307/2582903](https://doi.org/10.2307/2582903)

* [FrGe06] **A. Frangioni, C. Gentile.** "Solving nonlinear single-unit commitment problems with ramping constraints" Operations Research 54(4), p. 767 - 775, 2006. [DOI: 10.1287/opre.1060.0309](https://doi.org/10.1287/opre.1060.0309)

* [TeLuSa19] **D. A. Tejada-Arango, S. Lumbreras, P. Sanchez-Martin and A. Ramos.** "Which Unit-Commitment Formulation is Best? A Systematic Comparison," in IEEE Transactions on Power Systems. [DOI: 10.1109/TPWRS.2019.2962024](https://ieeexplore.ieee.org/document/8941313/).