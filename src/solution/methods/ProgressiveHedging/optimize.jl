# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.
using MPI, Printf
using TimerOutputs
import JuMP
const to = TimerOutput()

function optimize!(model::JuMP.Model, method::ProgressiveHedging)::PHFinalResult
    mpi = MpiInfo(MPI.COMM_WORLD)
    iterations = PHIterationInfo[]
    consensus_vars = [var for var in all_variables(model) if is_binary(var)]
    nvars = length(consensus_vars)
    weights = ones(nvars)
    if method.initial_weights !== nothing
        weights = copy(method.initial_weights)
    end
    target = zeros(nvars)
    if method.initial_target !== nothing
        target = copy(method.initial_target)
    end
    params = PHSubProblemParams(
        ρ = method.ρ,
        λ = [method.λ for _ in 1:nvars],
        target = target,
    )
    sp = PHSubProblem(model, model[:obj], consensus_vars, weights)
    while true
        iteration_time = @elapsed begin
            solution = solve_subproblem(sp, params, method.inner_method)
            MPI.Barrier(mpi.comm)
            global_obj = compute_global_objective(mpi, solution)
            target = compute_target(mpi, solution)
            update_λ_and_residuals!(solution, params, target)
            global_infeas = compute_global_infeasibility(solution, mpi)
            global_residual = compute_global_residual(mpi, solution)
            if has_numerical_issues(target)
                break
            end
        end
        total_elapsed_time =
            compute_total_elapsed_time(iteration_time, iterations)
        current_iteration = PHIterationInfo(
            global_infeas = global_infeas,
            global_obj = global_obj,
            global_residual = global_residual,
            iteration_number = length(iterations) + 1,
            iteration_time = iteration_time,
            sp_vals = solution.vals,
            sp_obj = solution.obj,
            target = target,
            total_elapsed_time = total_elapsed_time,
        )
        push!(iterations, current_iteration)
        print_progress(mpi, current_iteration, method.print_interval)
        if should_stop(mpi, iterations, method.termination)
            break
        end
    end
    return PHFinalResult(
        last(iterations).global_obj,
        last(iterations).sp_vals,
        last(iterations).total_elapsed_time,
    )
end

function compute_total_elapsed_time(
    iteration_time::Float64,
    iterations::Array{PHIterationInfo,1},
)::Float64
    length(iterations) > 0 ?
    current_total_time = last(iterations).total_elapsed_time :
    current_total_time = 0
    return current_total_time + iteration_time
end

function compute_global_objective(
    mpi::MpiInfo,
    s::PhSubProblemSolution,
)::Float64
    global_obj = MPI.Allreduce(s.obj, MPI.SUM, mpi.comm)
    global_obj /= mpi.nprocs
    return global_obj
end

function compute_target(mpi::MpiInfo, s::PhSubProblemSolution)::Array{Float64,1}
    sp_vals = s.vals
    target = MPI.Allreduce(sp_vals, MPI.SUM, mpi.comm)
    target = target / mpi.nprocs
    return target
end

function compute_global_residual(mpi::MpiInfo, s::PhSubProblemSolution)::Float64
    n_vars = length(s.vals)
    local_residual_sum = abs.(s.residuals)
    global_residual_sum = MPI.Allreduce(local_residual_sum, MPI.SUM, mpi.comm)
    return sum(global_residual_sum) / n_vars
end

function compute_global_infeasibility(
    solution::PhSubProblemSolution,
    mpi::MpiInfo,
)::Float64
    local_infeasibility = norm(solution.residuals)
    global_infeas = MPI.Allreduce(local_infeasibility, MPI.SUM, mpi.comm)
    return global_infeas
end

function solve_subproblem(
    sp::PHSubProblem,
    params::PHSubProblemParams,
    method::SolutionMethod,
)::PhSubProblemSolution
    G = length(sp.consensus_vars)
    if norm(params.λ) < 1e-3
        @objective(sp.mip, Min, sp.obj)
    else
        @objective(
            sp.mip,
            Min,
            sp.obj +
            sum(
                sp.weights[g] *
                params.λ[g] *
                (sp.consensus_vars[g] - params.target[g]) for g in 1:G
            ) +
            (params.ρ / 2) * sum(
                sp.weights[g] * (sp.consensus_vars[g] - params.target[g])^2 for
                g in 1:G
            )
        )
    end
    optimize!(sp.mip, method)
    obj = objective_value(sp.mip)
    sp_vals = value.(sp.consensus_vars)
    return PhSubProblemSolution(obj = obj, vals = sp_vals, residuals = zeros(G))
end

function update_λ_and_residuals!(
    solution::PhSubProblemSolution,
    params::PHSubProblemParams,
    target::Array{Float64,1},
)::Nothing
    n_vars = length(solution.vals)
    params.target = target
    for n in 1:n_vars
        solution.residuals[n] = solution.vals[n] - params.target[n]
        params.λ[n] += params.ρ * solution.residuals[n]
    end
end

function print_header(mpi::MpiInfo)::Nothing
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
    mpi::MpiInfo,
    iteration::PHIterationInfo,
    print_interval,
)::Nothing
    if !mpi.root
        return
    end
    if iteration.iteration_number % print_interval != 0
        return
    end
    @info @sprintf(
        "%8d %20.6e %20.6e %12.2f %% %8.2f %8.2f",
        iteration.iteration_number,
        iteration.global_obj,
        iteration.global_infeas,
        iteration.global_residual * 100,
        iteration.iteration_time,
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
    mpi::MpiInfo,
    iterations::Array{PHIterationInfo,1},
    termination::PHTermination,
)::Bool
    if length(iterations) >= termination.max_iterations
        if mpi.root
            @info "Iteration limit reached. Stopping."
        end
        return true
    end

    if length(iterations) < termination.min_iterations
        return false
    end

    if last(iterations).total_elapsed_time > termination.max_time
        if mpi.root
            @info "Time limit reached. Stopping."
        end
        return true
    end

    curr_it = last(iterations)
    prev_it = iterations[length(iterations)-1]

    if curr_it.global_infeas < termination.min_feasibility
        obj_change = abs(prev_it.global_obj - curr_it.global_obj)
        if obj_change < termination.min_improvement
            if mpi.root
                @info "Feasibility limit reached. Stopping."
            end
            return true
        end
    end
    return false
end
