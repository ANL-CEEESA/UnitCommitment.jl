# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using JuMP, MPI, TimerOutputs

Base.@kwdef mutable struct PHTermination
    max_iterations::Int = 1000
    max_time::Float64 = 14400.0
    min_feasibility::Float64 = 1e-3
    min_improvement::Float64 = 1e-3
    min_iterations::Int = 2
end

Base.@kwdef mutable struct PHIterationInfo
    global_infeas::Float64
    global_obj::Float64
    global_residual::Float64
    iteration_number::Int
    iteration_time::Float64
    sp_vals::Array{Float64,1}
    sp_obj::Float64
    target::Array{Float64,1}
    total_elapsed_time::Float64
end

Base.@kwdef mutable struct ProgressiveHedging <: SolutionMethod
    initial_weights::Union{Vector{Float64},Nothing} = nothing
    initial_target::Union{Vector{Float64},Nothing} = nothing
    ρ::Float64 = 1.0
    λ::Float64 = 0.0
    print_interval::Int = 1
    termination::PHTermination = PHTermination()
    inner_method::SolutionMethod = XavQiuWanThi2019.Method()
end

struct SpResult
    obj::Float64
    vals::Array{Float64,1}
end

Base.@kwdef mutable struct PHSubProblem
    mip::JuMP.Model
    obj::AffExpr
    consensus_vars::Array{VariableRef,1}
    weights::Array{Float64,1}
end

Base.@kwdef struct PhSubProblemSolution
    obj::Float64
    vals::Array{Float64,1}
    residuals::Array{Float64,1}
end

Base.@kwdef mutable struct PHSubProblemParams
    ρ::Float64
    λ::Array{Float64,1}
    target::Array{Float64,1}
end

struct MpiInfo
    comm::Any
    rank::Int
    root::Bool
    nprocs::Int

    function MpiInfo(comm)
        rank = MPI.Comm_rank(comm) + 1
        is_root = (rank == 1)
        nprocs = MPI.Comm_size(comm)
        return new(comm, rank, is_root, nprocs)
    end
end
