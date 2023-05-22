# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.
using MPI, Printf
using TimerOutputs
import JuMP
const to = TimerOutput()

function optimize!(
    model::JuMP.Model,
    method::ProgressiveHedging.Method,
)::ProgressiveHedging.FinalResult
    mpi = ProgressiveHedging.MpiInfo(MPI.COMM_WORLD)
    iterations = Array{ProgressiveHedging.IterationInfo,1}(undef, 0)
    if method.consensus_vars === nothing
        method.consensus_vars =
            [var for var in all_variables(model) if is_binary(var)]
    end
    nvars = length(method.consensus_vars)
    if method.weights === nothing
        method.weights = [1.0 for _ in 1:nvars]
    end
    if method.initial_global_consensus_vals === nothing
        method.initial_global_consensus_vals = [0.0 for _ in 1:nvars]
    end

    ph_sp_params = ProgressiveHedging.SpParams(
        ρ = method.ρ,
        λ = [method.λ_default for _ in 1:nvars],
        global_consensus_vals = method.initial_global_consensus_vals,
    )
    ph_subproblem = ProgressiveHedging.SubProblem(
        model,
        model[:obj],
        method.consensus_vars,
        method.weights,
    )
    set_optimizer_attribute(model, "Threads", method.num_of_threads)
    while true
        it_time = @elapsed begin
            solution = solve_subproblem(ph_subproblem, ph_sp_params)
            MPI.Barrier(mpi.comm)
            global_obj = compute_global_objective(mpi, solution)
            global_consensus_vals = compute_global_consensus(mpi, solution)
            update_λ_and_residuals!(
                solution,
                ph_sp_params,
                global_consensus_vals,
            )
            global_infeas = compute_global_infeasibility(solution, mpi)
            global_residual = compute_global_residual(mpi, solution)
            if has_numerical_issues(global_consensus_vals)
                break
            end
        end
        total_elapsed_time = compute_total_elapsed_time(it_time, iterations)
        it = ProgressiveHedging.IterationInfo(
            it_num = length(iterations) + 1,
            sp_consensus_vals = solution.consensus_vals,
            global_consensus_vals = global_consensus_vals,
            sp_obj = solution.obj,
            global_obj = global_obj,
            it_time = it_time,
            total_elapsed_time = total_elapsed_time,
            global_residual = global_residual,
            global_infeas = global_infeas,
        )
        iterations = [iterations; it]
        print_progress(mpi, it, method.print_interval)
        if should_stop(mpi, iterations, method.termination_criteria)
            break
        end
    end

    return ProgressiveHedging.FinalResult(
        last(iterations).global_obj,
        last(iterations).sp_consensus_vals,
        last(iterations).global_infeas,
        last(iterations).it_num,
        last(iterations).total_elapsed_time,
    )
end

function compute_total_elapsed_time(
    it_time::Float64,
    iterations::Array{ProgressiveHedging.IterationInfo,1},
)::Float64
    length(iterations) > 0 ?
    current_total_time = last(iterations).total_elapsed_time :
    current_total_time = 0
    return current_total_time + it_time
end

function compute_global_objective(
    mpi::ProgressiveHedging.MpiInfo,
    s::ProgressiveHedging.SpSolution,
)::Float64
    global_obj = MPI.Allreduce(s.obj, MPI.SUM, mpi.comm)
    global_obj /= mpi.nprocs
    return global_obj
end

function compute_global_consensus(
    mpi::ProgressiveHedging.MpiInfo,
    s::ProgressiveHedging.SpSolution,
)::Array{Float64,1}
    sp_consensus_vals = s.consensus_vals
    global_consensus_vals = MPI.Allreduce(sp_consensus_vals, MPI.SUM, mpi.comm)
    global_consensus_vals = global_consensus_vals / mpi.nprocs
    return global_consensus_vals
end

function compute_global_residual(
    mpi::ProgressiveHedging.MpiInfo,
    s::ProgressiveHedging.SpSolution,
)::Float64
    n_vars = length(s.consensus_vals)
    local_residual_sum = abs.(s.residuals)
    global_residual_sum = MPI.Allreduce(local_residual_sum, MPI.SUM, mpi.comm)
    return sum(global_residual_sum) / n_vars
end

function compute_global_infeasibility(
    solution::ProgressiveHedging.SpSolution,
    mpi::ProgressiveHedging.MpiInfo,
)::Float64
    local_infeasibility = norm(solution.residuals)
    global_infeas = MPI.Allreduce(local_infeasibility, MPI.SUM, mpi.comm)
    return global_infeas
end

function solve_subproblem(
    sp::ProgressiveHedging.SubProblem,
    ph_sp_params::ProgressiveHedging.SpParams,
)::ProgressiveHedging.SpSolution
    G = length(sp.consensus_vars)
    if norm(ph_sp_params.λ) < 1e-3
        @objective(sp.mip, Min, sp.obj)
    else
        @objective(
            sp.mip,
            Min,
            sp.obj +
            sum(
                sp.weights[g] *
                ph_sp_params.λ[g] *
                (sp.consensus_vars[g] - ph_sp_params.global_consensus_vals[g])
                for g in 1:G
            ) +
            (ph_sp_params.ρ / 2) * sum(
                sp.weights[g] *
                (
                    sp.consensus_vars[g] -
                    ph_sp_params.global_consensus_vals[g]
                )^2 for g in 1:G
            )
        )
    end
    optimize!(sp.mip, XavQiuWanThi2019.Method())
    obj = objective_value(sp.mip)
    sp_consensus_vals = value.(sp.consensus_vars)
    return ProgressiveHedging.SpSolution(
        obj = obj,
        consensus_vals = sp_consensus_vals,
        residuals = zeros(G),
    )
end

function update_λ_and_residuals!(
    solution::ProgressiveHedging.SpSolution,
    ph_sp_params::ProgressiveHedging.SpParams,
    global_consensus_vals::Array{Float64,1},
)::Nothing
    n_vars = length(solution.consensus_vals)
    ph_sp_params.global_consensus_vals = global_consensus_vals
    for n in 1:n_vars
        solution.residuals[n] =
            solution.consensus_vals[n] - ph_sp_params.global_consensus_vals[n]
        ph_sp_params.λ[n] += ph_sp_params.ρ * solution.residuals[n]
    end
end

function print_header(mpi::ProgressiveHedging.MpiInfo)::Nothing
    if !mpi.root
        return
    end
    @info "Solving via Progressive Hedging:"
    @info @sprintf(
        "%8s %20s %20s %14s %8s %8s",
        "iter",
        "obj",
        "infeas",
        "consensus",
        "time-it",
        "time"
    )
end

function print_progress(
    mpi::ProgressiveHedging.MpiInfo,
    iteration::ProgressiveHedging.IterationInfo,
    print_interval,
)::Nothing
    if !mpi.root
        return
    end
    if iteration.it_num % print_interval != 0
        return
    end
    @info @sprintf(
        "Current iteration %8d %20.6e %20.6e %12.2f %% %8.2f %8.2f",
        iteration.it_num,
        iteration.global_obj,
        iteration.global_infeas,
        iteration.global_residual * 100,
        iteration.it_time,
        iteration.total_elapsed_time
    )
end

function has_numerical_issues(target::Array{Float64,1})::Bool
    if target == NaN
        @warn "Numerical issues detected. Stopping."
        return true
    end
    return false
end

function should_stop(
    mpi::ProgressiveHedging.MpiInfo,
    iterations::Array{ProgressiveHedging.IterationInfo,1},
    criteria::ProgressiveHedging.TerminationCriteria,
)::Bool
    if length(iterations) >= criteria.max_iterations
        if mpi.root
            @info "Iteration limit reached. Stopping."
        end
        return true
    end

    if length(iterations) < criteria.min_iterations
        return false
    end

    if last(iterations).total_elapsed_time > criteria.max_time
        if mpi.root
            @info "Time limit reached. Stopping."
        end
        return true
    end

    curr_it = last(iterations)
    prev_it = iterations[length(iterations)-1]

    if curr_it.global_infeas < criteria.min_feasibility
        obj_change = abs(prev_it.global_obj - curr_it.global_obj)
        if obj_change < criteria.min_improvement
            if mpi.root
                @info "Feasibility limit reached. Stopping."
            end
            return true
        end
    end
    return false
end
