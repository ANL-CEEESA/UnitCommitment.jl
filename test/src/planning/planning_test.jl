# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using UnitCommitment
using JuMP
using SCIP
using JSON
import UnitCommitment:
	PhaseAngleFormulation


function _test_plan(
	; formulation::Formulation = Formulation(transmission = PhaseAngleFormulation()),
	instances = ["tep_garver6"],
	dump::Bool = false,
	stochastic::Bool = false,
)::Nothing
	for instance_name in instances
		if stochastic
			instance = UnitCommitment.read([fixture("$(instance_name).json.gz"), fixture("$(instance_name).json.gz")])
		else
			instance = UnitCommitment.read(fixture("$(instance_name).json.gz"))
		end
		model = UnitCommitment.build_model(
			instance = instance,
			formulation = formulation,
			optimizer = SCIP.Optimizer,
			variable_names = true,
		)
		set_silent(model)
		UnitCommitment.optimize!(model)
		solution = UnitCommitment.solution(model)
		if dump
			open("/tmp/ucjl.json", "w") do f
				return write(f, JSON.json(solution, 2))
			end
			write_to_file(model, "/tmp/ucjl.lp")
		end
		@test UnitCommitment.validate(instance, solution)
	end
	return
end

function model_planning_test()
	@testset "planning" begin
		@testset "ieee24" begin
			_test_plan(instances = ["tep_ieee24"])
		end
		@testset "tep_ieee24_uc" begin
			_test_plan(
				formulation = Formulation(
					transmission = PhaseAngleFormulation(),
				),
				instances = ["tep_ieee24_uc"],
			)
		end
		@testset "tep_ieee24_stoch" begin
			_test_plan(
				formulation = Formulation(
					transmission = PhaseAngleFormulation(),
				),
				instances = ["tep_ieee24"],
				stochastic = true,
			)
		end
	end
end
