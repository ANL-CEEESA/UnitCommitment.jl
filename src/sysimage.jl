# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using PackageCompiler

using DataStructures
using Documenter
using GLPK
using JSON
using JuMP
using MathOptInterface
using SparseArrays
using TimerOutputs

pkg = [:DataStructures,
       :Documenter,
       :GLPK,
       :JSON,
       :JuMP,
       :MathOptInterface,
       :SparseArrays,
       :TimerOutputs]

@info "Building system image..."
create_sysimage(pkg, sysimage_path="build/sysimage.so")
