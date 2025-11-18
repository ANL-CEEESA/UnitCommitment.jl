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
	instances = ["tep_ieee14"],
	dump::Bool = false,
)::Nothing
	for instance_name in instances
		instance = UnitCommitment.read([fixture("$(instance_name).json"), fixture("$(instance_name).json")]) # add .gz before shipping
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
		@testset "default" begin
			_test_plan()
		end
		@testset "ieee14" begin
			_test_plan(instances = ["tep_ieee14"])
		end
		@testset "ieee24" begin
			_test_plan(instances = ["tep_ieee24"])
		end
		@testset "ieee30" begin
			_test_plan(instances = ["tep_ieee30"])
		end
		@testset "ieee118" begin
			_test_plan(instances = ["tep_ieee118"])
		end
		@testset "ieee300" begin
			_test_plan(instances = ["tep_ieee300"])
		end
		@testset "north_brazilian" begin
			_test_plan(instances = ["tep_north_brazilian"])
		end
		@testset "south_brazilian" begin
			_test_plan(instances = ["tep_south_brazilian"])
		end
		@testset "polish2383" begin
			_test_plan(instances = ["tep_polish2383"])
		end

		@testset "unitcommitment_ieee14" begin
			_test_plan(
				formulation = Formulation(
					transmission = PhaseAngleFormulation(),
				),
				instances = ["tep_ieee14"],
			)
		end

		@testset "stochastic_ieee14" begin
			_test_plan(
				formulation = Formulation(
					transmission = PhaseAngleFormulation(),
				),
				instances = ["tep_ieee14"],
				dump = true,
			)
		end
	end
end
