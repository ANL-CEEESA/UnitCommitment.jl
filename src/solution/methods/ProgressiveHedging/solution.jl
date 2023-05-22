# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using MPI, DataStructures
const FIRST_STAGE_VARS = ["Is on", "Switch on", "Switch off"]

function solution(
    model::JuMP.Model,
    method::ProgressiveHedging.Method,
)::OrderedDict
    comm = MPI.COMM_WORLD
    mpi = ProgressiveHedging.MpiInfo(comm)
    sp_solution = UnitCommitment.solution(model)
    gather_solution = OrderedDict()
    for (solution_key, dict) in sp_solution
        if solution_key !== "Spinning reserve (MW)" &&
           solution_key ∉ FIRST_STAGE_VARS
            push!(gather_solution, solution_key => OrderedDict())
            for (gen_bus_key, values) in dict
                global T = length(values)
                receive_values =
                    MPI.UBuffer(Vector{Float64}(undef, T * mpi.nprocs), T)
                MPI.Gather!(float.(values), receive_values, comm)
                if mpi.root
                    push!(
                        gather_solution[solution_key],
                        gen_bus_key => receive_values.data,
                    )
                end
            end
        end
    end
    push!(gather_solution, "Spinning reserve (MW)" => OrderedDict())
    for (reserve_type, dict) in sp_solution["Spinning reserve (MW)"]
        push!(
            gather_solution["Spinning reserve (MW)"],
            reserve_type => OrderedDict(),
        )
        for (gen_key, values) in dict
            receive_values =
                MPI.UBuffer(Vector{Float64}(undef, T * mpi.nprocs), T)
            MPI.Gather!(float.(values), receive_values, comm)
            if mpi.root
                push!(
                    gather_solution["Spinning reserve (MW)"][reserve_type],
                    gen_key => receive_values.data,
                )
            end
        end
    end
    aggregate_solution = OrderedDict()
    if mpi.root
        for first_stage_var in FIRST_STAGE_VARS
            aggregate_solution[first_stage_var] = OrderedDict()
            for gen_key in keys(sp_solution[first_stage_var])
                aggregate_solution[first_stage_var][gen_key] =
                    sp_solution[first_stage_var][gen_key]
            end
        end
        for i in 1:mpi.nprocs
            push!(aggregate_solution, "s$i" => OrderedDict())
            for (solution_key, solution_dict) in gather_solution
                push!(aggregate_solution["s$i"], solution_key => OrderedDict())
                if solution_key !== "Spinning reserve (MW)"
                    for (gen_bus_key, values) in solution_dict
                        aggregate_solution["s$i"][solution_key][gen_bus_key] =
                            gather_solution[solution_key][gen_bus_key][(i-1)*T+1:i*T]
                    end
                else
                    for (reserve_name, reserve_dict) in solution_dict
                        push!(
                            aggregate_solution["s$i"][solution_key],
                            reserve_name => OrderedDict(),
                        )
                        for (gen_key, values) in reserve_dict
                            aggregate_solution["s$i"][solution_key][reserve_name][gen_key] =
                                gather_solution[solution_key][reserve_name][gen_key][(i-1)*T+1:i*T]
                        end
                    end
                end
            end
        end
    end
    return aggregate_solution
end
