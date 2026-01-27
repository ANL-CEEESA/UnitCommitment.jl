# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using UnitCommitment
using JuMP
using SCIP
using JSON
# using DataFrames
# using CSV
import UnitCommitment:
	PhaseAngleFormulation

function _solve_planning(
	results_df::Vector;
	instance_name::String,
	formulation::Formulation = Formulation(transmission = PhaseAngleFormulation()),
	stochastic::Bool = false,
)
	if stochastic
		instance = UnitCommitment.read([fixture("$(instance_name).json.gz"), fixture("$(instance_name).json.gz")])
	else
		instance = UnitCommitment.read(fixture("$(instance_name).json.gz"))
	end

	sc = instance.scenarios[1]
	cand_lines = sum(l -> l.invest[1] > 1e-5 ? l.max_copy : 0, sc.lines)
	cand_gens = count(u -> u.invest[1] > 1e-5, sc.thermal_units) +
				count(u -> u.invest[1] > 1e-5, sc.profiled_units)

	model = UnitCommitment.build_model(
		instance = instance,
		formulation = formulation,
		optimizer = SCIP.Optimizer,
		variable_names = true,
	)
	set_silent(model)
	UnitCommitment.optimize!(model)
	solution = UnitCommitment.solution(model)
	solve_time_sec = solve_time(model)
	opt_cost = objective_value(model)

	lines_built = 0
	punits_built = 0
	thermals_built = 0

	if haskey(solution, "Line investment status")
		for (name, val_array) in solution["Line investment status"]
			if !isempty(val_array)
				max_val = maximum(val_array)
				if max_val > 0.5
					lines_built += Int(round(max_val))
				end
			end
		end
	end

	if haskey(solution, "Unit investment status")
		for (name, val_array) in solution["Unit investment status"]
			if !isempty(val_array)
				max_val = maximum(val_array)
				if max_val > 0.5
					punits_built += Int(round(max_val))
				end
			end
		end
	end

	if haskey(solution, "Thermal investment status")
		for (name, val_array) in solution["Thermal investment status"]
			if !isempty(val_array)
				max_val = maximum(val_array)
				if max_val > 0.5
					thermals_built += Int(round(max_val))
				end
			end
		end
	end

	push!(
		results_df,
		(
			Instance = instance_name,
			SolveTime = solve_time_sec,
			CandidateLines = cand_lines,
			CandidateGens = cand_gens,
			OptimalCost = opt_cost,
			LinesBuilt = lines_built,
			ProfiledsBuilt = punits_built,
			ThermalsBuilt = thermals_built,
			Vars = num_variables(model),
			Constrs = num_constraints(model; count_variable_in_set_constraints = false),
			IsStochastic = stochastic,
		),
	)
end


function model_planning_test_bench_table()
	@testset "planning_benchmark" begin
		results = []

		instance_list = [
			"tep_garver6",
			"tep_ieee14",
			"tep_ieee24",
			"tep_ieee30",
			"tep_ieee118",
			"tep_ieee300",
			# "tep_north_brazilian",
			"tep_south_brazilian",
			# "tep_polish2383",
			"tep_ieee24_uc",
		]

		for inst in instance_list
			_solve_planning(results, instance_name = inst)
		end

		# Stochastic
		_solve_planning(results, instance_name = "tep_ieee24", stochastic = true)

		open("/tmp/planning_bench.csv", "w") do f
			println(f, "Instance,SolveTime,OptimalCost,CandidateLines,CandidateGens,LinesBuilt,ProfiledsBuilt,ThermalsBuilt,Vars,Constrs,IsStochastic")
			for r in results
				println(f, "$(r.Instance),$(r.SolveTime),$(r.OptimalCost),$(r.CandidateLines),$(r.CandidateGens),$(r.LinesBuilt),$(r.ProfiledsBuilt),$(r.ThermalsBuilt),$(r.Vars),$(r.Constrs),$(r.IsStochastic)")
			end
		end

		return
	end
end
