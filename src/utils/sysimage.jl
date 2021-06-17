# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using PackageCompiler

using DataStructures
using Distributions
using JSON
using JuMP
using MathOptInterface
using SparseArrays

pkg = [
    :DataStructures,
    :Distributions,
    :JSON,
    :JuMP,
    :MathOptInterface,
    :SparseArrays,
]

@info "Building system image..."
create_sysimage(
    pkg,
    precompile_statements_file = "build/precompile.jl",
    sysimage_path = "build/sysimage.so",
)
