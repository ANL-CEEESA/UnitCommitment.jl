# Changelog

## [0.2.0] - [Unreleased]

### Added
- Sub-hourly unit commitment

### Changed
- Renamed "Time (h)" parameter to "Time horizon (h)"
- `UnitCommitment.build_model` now returns a plain JuMP model. The
  struct `UnitCommitmentModel` has been completely removed. Accessing model elements can now be accomplished as follows:
    - `model.vars.x[idx]` becomes `model[:x][idx]`
    - `model.eqs.y[idx]` becomes `model[:eq_y][idx]`
    - `model.expr.z[idx]` becomes `model[:expr_z][idx]`
    - `model.obj` becomes `model[:obj]`
    - `model.isf` becomes `model[:isf]`
    - `model.lodf` becomes `model[:lodf]`
- Function `UnitCommitment.get_solution` has been renamed to `UnitCommitment.solution`

## [0.1.1] - 2020-11-16

* Fixes to MATLAB and PGLIB-UC instances
* Add OR-LIB and Tejada19 instances
* Improve documentation

## [0.1.0] - 2020-11-06

* Initial public release
