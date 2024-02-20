JuMP Model
==========

In this page, we describe the JuMP optimization model produced by the function `build_model`. A detailed understanding of this model is not necessary if you are just interested in using the package to solve some standard unit commitment cases, but it may be useful, for example, if you need to solve a slightly different problem, with additional variables and constraints. The notation in this page generally follows [KnOsWa20].

Decision variables
------------------

UC.jl models the security-constrained unit commitment problem as a two-stage stochastic program. In this approach, some of the decision variables are *first-stage decisions*, which are taken before the uncertainty is realized and must therefore be the same across all scenarios, while the remaining variables are *second-stage decisions*, which can attain a different values in each scenario. In the current version of the package, all binary variables (which model commitment decisions of thermal units) are first-stage decisions and all continuous variables are second-stage decisions.

!!! note

    UC.jl treats deterministic SCUC instances as a special case of the stochastic problem in which there is only one scenario, named `"s1"` by default. To access second-stage decisions, therefore, you must provide this scenario name as the value for `sn`. For example, `model[:prod_above]["s1", g, t]`. 

### Generators

In this section, we describe the decision variables associated with the generators, which include both thermal units (e.g., natural gas-fired power plant) and profiled units (e.g., wind turbine). 

#### Thermal Units

Name |  Description | Unit | Stage
:-----|:-------------|:------: | :------:
`is_on[g,t]` | True if generator `g` is on at time `t`. | Binary | 1
`switch_on[g,t]` | True is generator `g` switches on at time `t`. | Binary| 1
`switch_off[g,t]` | True if generator `g` switches off at time `t`. | Binary| 1
`startup[g,t,s]` | True if generator `g` switches on at time `t` incurring start-up costs from start-up category `s`. | Binary| 1
`prod_above[sn,g,t]` | Amount of power produced by generator `g` above its minimum power output at time `t` in scenario `sn`. For example, if the minimum power of generator `g` is 100 MW and `g` is producing 115 MW of power at time `t` in scenario `sn`, then `prod_above[sn,g,t]` equals `15.0`. | MW | 2
`segprod[sn,g,t,k]` | Amount of power from piecewise linear segment `k` produced by generator `g` at time `t` in scenario `sn`. For example, if cost curve for generator `g` is defined by the points `(100, 1400)`, `(110, 1600)`, `(130, 2200)` and `(135, 2400)`, and if the generator is producing 115 MW of power at time `t` in scenario `sn`, then `segprod[sn,g,t,:]` equals `[10.0, 5.0, 0.0]`.| MW | 2
`reserve[sn,r,g,t]` | Amount of reserve `r` provided by unit `g` at time `t` in scenario `sn`. | MW | 2

!!! warning

    The first-stage decision variables of the JuMP model are `is_on[g,t]`, `switch_on[g,t]`, `switch_off[g,t]`, and `startup[g,t,s]`. As such, the dictionaries corresponding to these variables do not include the scenario index in their keys. In contrast, all other variables of the created JuMP model are allowed to obtain a different value in each scenario and are thus modeled as second-stage decision variables. Accordingly, the dictionaries of all second-stage decision variables have the scenario index in their keys. This is true even if the model is created to solve the deterministic SCUC, in which case the default scenario index `s1` is included in the dictionary key.
    

#### Profiled Units

Name | Description | Unit | Stage
:-----|:-------------|:------: | :------:
`prod_profiled[s,t]` | Amount of power produced by profiled unit `g` at time `t`. | MW | 2


### Buses

Name | Description | Unit | Stage
:-----|:-------------|:------:| :------:
`net_injection[sn,b,t]` | Net injection at bus `b` at time `t` in scenario `sn`. | MW | 2
`curtail[sn,b,t]` | Amount of load curtailed at bus `b` at time `t` in scenario `sn`. | MW | 2


### Price-sensitive loads

Name |  Description | Unit | Stage
:-----|:-------------|:------:| :------:
`loads[sn,s,t]` | Amount of power served to price-sensitive load `s` at time `t` in scenario `sn`. | MW | 2

### Transmission lines

Name |  Description | Unit | Stage 
:-----|:-------------|:------:| :------:
`flow[sn,l,t]` |  Power flow on line `l` at time `t` in scenario `sn`. | MW | 2
`overflow[sn,l,t]` | Amount of flow above the limit for line `l` at time `t` in scenario `sn`. | MW | 2

!!! warning

    Since transmission and N-1 security constraints are enforced in a lazy way, most of the `flow[l,t]` variables are never added to the model. Accessing `model[:flow][sn,l,t]` without first checking that the variable exists will likely generate an error.

Objective function
------------------

TODO

Constraints
-----------

TODO


