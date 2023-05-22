# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

module ProgressiveHedging
using JuMP, MPI, TimerOutputs
import ..SolutionMethod

mutable struct TerminationCriteria
    max_iterations::Int
    max_time::Float64
    min_feasibility::Float64
    min_improvement::Float64
    min_iterations::Int

    function TerminationCriteria(;
        max_iterations::Int = 1000,
        max_time::Float64 = 14400.0,
        min_feasibility::Float64 = 1e-3,
        min_improvement::Float64 = 1e-3,
        min_iterations::Int = 2,
    )
        return new(
            max_iterations,
            max_time,
            min_feasibility,
            min_improvement,
            min_iterations,
        )
    end
end

Base.@kwdef mutable struct IterationInfo
    it_num::Int
    sp_consensus_vals::Array{Float64,1}
    global_consensus_vals::Array{Float64,1}
    sp_obj::Float64
    global_obj::Float64
    it_time::Float64
    total_elapsed_time::Float64
    global_residual::Float64
    global_infeas::Float64
end

mutable struct Method <: SolutionMethod
    consensus_vars::Union{Array{VariableRef,1},Nothing}
    weights::Union{Array{Float64,1},Nothing}
    initial_global_consensus_vals::Union{Array{Float64,1},Nothing}
    num_of_threads::Int
    ρ::Float64
    λ_default::Float64
    print_interval::Int
    termination_criteria::TerminationCriteria

    function Method(;
        consensus_vars::Union{Array{VariableRef,1},Nothing} = nothing,
        weights::Union{Array{Float64,1},Nothing} = nothing,
        initial_global_consensus_vals::Union{Array{Float64,1},Nothing} = nothing,
        num_of_threads::Int = 1,
        ρ::Float64 = 1.0,
        λ_default::Float64 = 0.0,
        print_interval::Int = 1,
        termination_criteria::TerminationCriteria = TerminationCriteria(),
    )
        return new(
            consensus_vars,
            weights,
            initial_global_consensus_vals,
            num_of_threads,
            ρ,
            λ_default,
            print_interval,
            termination_criteria,
        )
    end
end

struct FinalResult
    obj::Float64
    vals::Any
    infeasibility::Float64
    total_iteration_num::Int
    wallclock_time::Float64
end

struct SpResult
    obj::Float64
    vals::Array{Float64,1}
end

Base.@kwdef mutable struct SubProblem
    mip::JuMP.Model
    obj::AffExpr
    consensus_vars::Array{VariableRef,1}
    weights::Array{Float64,1}
end

Base.@kwdef struct SpSolution
    obj::Float64
    consensus_vals::Array{Float64,1}
    residuals::Array{Float64,1}
end

Base.@kwdef mutable struct SpParams
    ρ::Float64
    λ::Array{Float64,1}
    global_consensus_vals::Array{Float64,1}
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

Base.@kwdef struct Callbacks
    before_solve_subproblem::Any
    after_solve_subproblem::Any
    after_iteration::Any
end

end
