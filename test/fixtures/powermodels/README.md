# PowerModels Test Cases

This directory contains test cases automatically converted from [PowerModels.jl](https://github.com/lanl-ansi/PowerModels.jl) for validation purposes.

## Generation

Files were generated using `scripts/matpower_to_ucjl.jl`, which:
1. Parses MATPOWER `.m` files
2. Converts them to UnitCommitment.jl 0.5 JSON format
3. Solves various OPF/PF problems (AC/DC/SOC) for reference solutions

## Structure

Each case subdirectory contains:
- `converted.json` — UnitCommitment.jl instance converted from PowerModels data
- `converted.log` — Conversion details
- `original.m` — Original MATPOWER case file
- `sol_*.json` — Reference solutions from various formulations (AC OPF, DC OPF, SOC OPF, AC PF, DC PF)
