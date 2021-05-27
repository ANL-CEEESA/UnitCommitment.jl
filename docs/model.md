```{sectnum}
---
start: 4
depth: 2
suffix: .
---
```

JuMP Model
==========

In this page, we describe the JuMP optimization model produced by the function `UnitCommitment.build_model`. A detailed understanding of this model is not necessary if you are just interested in using the package to solve some standard unit commitment cases, but it may be useful, for example, if you need to solve a slightly different problem, with additional variables and constraints.

The notation in this page generally follows [KnOsWa20].


Decision variables
------------------

### Generators

Name | Symbol | Description | Unit
-----|:--------:|-------------|:------:
`is_on[g,t]` | $u_{g}(t)$ | True if generator `g` is on at time `t`. | Binary
`switch_on[g,t]` | $v_{g}(t)$ | True is generator `g` switches on at time `t`. | Binary
`switch_off[g,t]` | $w_{g}(t)$ | True if generator `g` switches off at time `t`. | Binary
`prod_above[g,t]` |$p'_{g}(t)$ | Amount of power produced by generator `g` above its minimum power output at time `t`. For example, if the minimum power of generator `g` is 100 MW and `g` is producing 115 MW of power at time `t`, then `prod_above[g,t]` equals `15.0`. | MW
`segprod[g,t,l]` | $p^l_g(t)$ | Amount of power from piecewise linear segment `l` produced by generator `g` at time `t`. For example, if cost curve for generator `g` is defined by the points `(100, 1400)`, `(110, 1600)`, `(130, 2200)` and `(135, 2400)`, and if the generator is producing 115 MW of power at time `t`, then `segprod[g,t,:]` equals `[10.0, 5.0, 0.0]`.| MW
`reserve[g,t]` | $r_g(t)$ | Amount of reserves provided by generator `g` at time `t`. | MW
`startup[g,t,s]` | $\delta^s_g(t)$ | True if generator `g` switches on at time `t` incurring start-up costs from start-up type `s`. | Binary


### Buses

Name | Symbol | Description | Unit
-----|:------:|-------------|:------:
`net_injection[b,t]` | $n_b(t)$ | Net injection at bus `b` at time `t`. | MW
`curtail[b,t]` | $s^+_b(t)$ | Amount of load curtailed at bus `b` at time `t` | MW


### Price-sensitive loads

Name | Symbol | Description | Unit
-----|:------:|-------------|:------:
`loads[ps,t]` | $d_{ps}(t)$ | Amount of power served to price-sensitive load `ps` at time `t`. | MW

### Transmission lines

Name | Symbol | Description | Unit
-----|:------:|-------------|:------:
`flow[l,t]` | $f_l(t)$ | Power flow on line `l` at time `t`. | MW
`overflow[l,t]` | $f^+_l(t)$ | Amount of flow above the limit for line `l` at time `t`. | MW

```{danger}

Since transmission and N-1 security constraints are enforced in a lazy way, most of the variables `flow[l,t]` and `overflow[l,t]` are never added to the model. Accessing `model[:flow][l,t]`, for example, without first checking that the variable exists will generate an error.
```

Objective function
------------------

$$
\begin{align*}
    \text{minimize} \;\; &
        \sum_{s \in PS} x
\end{align*}
$$


Constraints
-----------



Querying the model
------------------




Modifying the model
-------------------

### Adding new constraints

Lorem ipsum dolor sit amet, consectetur adipiscing elit. Maecenas a euismod velit. Nulla semper ligula ex, sed maximus lacus eleifend quis. Nam efficitur magna eget lacinia sollicitudin. Vivamus placerat luctus velit, vitae consequat odio hendrerit sit amet. Quisque mattis elit a leo finibus interdum. Nunc aliquam sem lorem, nec feugiat magna feugiat id. Vestibulum ante ipsum primis in faucibus orci luctus et ultrices posuere cubilia curae; Aliquam malesuada sapien et ex lobortis, et maximus arcu sodales. Donec pretium leo lacus, a efficitur dui ultricies nec. Vestibulum et mauris risus. Vestibulum ante ipsum primis in faucibus orci luctus et ultrices posuere cubilia curae; Fusce finibus nunc ut neque scelerisque mollis. Etiam pretium, nulla et luctus lacinia, ante enim lobortis urna, eget tempus ante dolor non lorem.


### Removing existing constraints

Lorem ipsum dolor sit amet, consectetur adipiscing elit. Maecenas a euismod velit. Nulla semper ligula ex, sed maximus lacus eleifend quis. Nam efficitur magna eget lacinia sollicitudin. Vivamus placerat luctus velit, vitae consequat odio hendrerit sit amet. Quisque mattis elit a leo finibus interdum. Nunc aliquam sem lorem, nec feugiat magna feugiat id. Vestibulum ante ipsum primis in faucibus orci luctus et ultrices posuere cubilia curae; Aliquam malesuada sapien et ex lobortis, et maximus arcu sodales. Donec pretium leo lacus, a efficitur dui ultricies nec. Vestibulum et mauris risus. Vestibulum ante ipsum primis in faucibus orci luctus et ultrices posuere cubilia curae; Fusce finibus nunc ut neque scelerisque mollis. Etiam pretium, nulla et luctus lacinia, ante enim lobortis urna, eget tempus ante dolor non lorem.


References
----------
* [KnOsWa20] **Bernard Knueven, James Ostrowski and Jean-Paul Watson.** "On Mixed-Integer Programming Formulations for the Unit Commitment Problem". INFORMS Journal on Computing (2020). [DOI: 10.1287/ijoc.2019.0944](https://doi.org/10.1287/ijoc.2019.0944)

