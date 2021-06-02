# Changelog

All notable changes to this project will be documented in this file.

- The format is based on [Keep a Changelog][changelog].
- This project adheres to [Semantic Versioning][semver].
- For versions before 1.0, we follow the [Pkg.jl convention][pkjjl]
  that `0.a.b` is compatible with `0.a.c`.

[changelog]: https://keepachangelog.com/en/1.0.0/
[semver]: https://semver.org/spec/v2.0.0.html
[pkjjl]: https://pkgdocs.julialang.org/v1/compatibility/#compat-pre-1.0

## [0.2.1] - 2021-06-02
### Added
- Add multiple ramping formulations (ArrCon2000, MorLatRam2013, DamKucRajAta2016, PanGua2016)
- Add multiple piecewise-linear costs formulations (Garver1962, CarArr2006, KnuOstWat2018)
- Allow benchmark scripts to compare multiple formulations

## [0.2.0] - 2021-05-28
### Added
- Add sub-hourly unit commitment.
- Add `UnitCommitment.write(filename, solution)`.
- Add current mathematical formulation to the documentation.

### Changed
- Rename "Time (h)" parameter to "Time horizon (h)".
- Rename `UnitCommitment.get_solution` to `UnitCommitment.solution`, for better
  consistency with JuMP style.
- Add an underscore to the name of all functions that do not appear in the
  documentation (e.g. `something` becomes `_something`) These functions are not
  part of the public API and may change without notice, even in PATCH releases.
- The function `UnitCommitment.build_model` now returns a plain JuMP model. The
  struct `UnitCommitmentModel` has been completely removed. Accessing model
  elements can now be accomplished as follows:
    - `model.vars.x[idx]` becomes `model[:x][idx]`
    - `model.eqs.y[idx]` becomes `model[:eq_y][idx]`
    - `model.expr.z[idx]` becomes `model[:expr_z][idx]`
    - `model.obj` becomes `model[:obj]`
    - `model.isf` becomes `model[:isf]`
    - `model.lodf` becomes `model[:lodf]`

### Fixed
- Properly validate solutions with price-sensitive loads.

## [0.1.1] - 2020-11-16
### Added
- Add OR-LIB and Tejada19 instances.
- Improve documentation.

## Fixed
- Fixes to MATLAB and PGLIB-UC instances.

## [0.1.0] - 2020-11-06
- Initial public release.
