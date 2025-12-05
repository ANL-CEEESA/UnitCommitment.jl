# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using UnitCommitment, SCIP, HiGHS, JuMP
import UnitCommitment: MarketSettings

function simple_market_test()
	@testset "da-to-rt simple market" begin
		da_path = fixture("market_da_simple.json.gz")
		rt_paths = [
			fixture("market_rt1_simple.json.gz"),
			fixture("market_rt2_simple.json.gz"),
			fixture("market_rt3_simple.json.gz"),
			fixture("market_rt4_simple.json.gz"),
		]
		# solve market with default setting
		solution = UnitCommitment.solve_market(
			da_path,
			rt_paths,
			settings = MarketSettings(), # keep everything default
			optimizer = optimizer_with_attributes(SCIP.Optimizer, "display/verblevel" => 0),
			lp_optimizer = optimizer_with_attributes(
				HiGHS.Optimizer,
				"log_to_console" => false,
			),
		)

		# the commitment status must agree with DA market
		da_solution = solution["DA"]
		@test da_solution["Is on"]["GenY"] == [0.0, 1.0]
		@test da_solution["LMP (\$/MW)"][("s1", "B1", 1)] == 50.0
		@test da_solution["LMP (\$/MW)"][("s1", "B1", 2)] == 56.0

		rt_solution = solution["RT"]
		@test length(rt_solution) == 4
		@test rt_solution[1]["Is on"]["GenY"] == [0.0, 0.0]
		@test rt_solution[2]["Is on"]["GenY"] == [0.0, 1.0]
		@test rt_solution[3]["Is on"]["GenY"] == [1.0, 1.0]
		@test rt_solution[4]["Is on"]["GenY"] == [1.0]
		@test length(rt_solution[1]["LMP (\$/MW)"]) == 2
		@test length(rt_solution[2]["LMP (\$/MW)"]) == 2
		@test length(rt_solution[3]["LMP (\$/MW)"]) == 2
		@test length(rt_solution[4]["LMP (\$/MW)"]) == 1

		# solve market with no lmp method
		solution_no_lmp = UnitCommitment.solve_market(
			da_path,
			rt_paths,
			settings = MarketSettings(lmp_method = nothing), # no lmp
			optimizer = optimizer_with_attributes(SCIP.Optimizer, "display/verblevel" => 0),
		)

		# the commitment status must agree with DA market
		da_solution = solution_no_lmp["DA"]
		@test haskey(da_solution, "LMP (\$/MW)") == false
		rt_solution = solution_no_lmp["RT"][1]
		@test haskey(rt_solution, "LMP (\$/MW)") == false
	end
end

function stochastic_market_test()
	@testset "da-to-rt stochastic market" begin
		da_path = [
			fixture("market_da_simple.json.gz"),
			fixture("market_da_scenario.json.gz"),
		]
		rt_paths = [
			fixture("market_rt1_simple.json.gz"),
			fixture("market_rt2_simple.json.gz"),
			fixture("market_rt3_simple.json.gz"),
			fixture("market_rt4_simple.json.gz"),
		]
		# after build and after optimize 
		function after_build(model, instance)
			@constraint(model, model[:is_on]["GenY", 1] == 1,)
		end

		lmps_da = []
		lmps_rt = []

		function after_optimize_da(solution, model, instance)
			lmp = UnitCommitment.compute_lmp(
				model,
				ConventionalLMP(),
				optimizer = optimizer_with_attributes(
					HiGHS.Optimizer,
					"log_to_console" => false,
				),
			)
			return push!(lmps_da, lmp)
		end

		function after_optimize_rt(solution, model, instance)
			lmp = UnitCommitment.compute_lmp(
				model,
				ConventionalLMP(),
				optimizer = optimizer_with_attributes(
					HiGHS.Optimizer,
					"log_to_console" => false,
				),
			)
			return push!(lmps_rt, lmp)
		end

		# solve the stochastic market with callbacks
		solution = UnitCommitment.solve_market(
			da_path,
			rt_paths,
			settings = MarketSettings(), # keep everything default
			optimizer = optimizer_with_attributes(SCIP.Optimizer, "display/verblevel" => 0),
			lp_optimizer = optimizer_with_attributes(
				HiGHS.Optimizer,
				"log_to_console" => false,
			),
			after_build_da = after_build,
			after_optimize_da = after_optimize_da,
			after_optimize_rt = after_optimize_rt,
		)
		# the commitment status must agree with DA market
		da_solution_sp = solution["DA"]["market_da_simple"]
		da_solution_sc = solution["DA"]["market_da_scenario"]
		@test da_solution_sc["Is on"]["GenY"] == [1.0, 1.0]
		@test da_solution_sp["LMP (\$/MW)"][("market_da_simple", "B1", 1)] ==
			  25.0
		@test da_solution_sc["LMP (\$/MW)"][("market_da_scenario", "B1", 2)] ==
			  0.0

		rt_solution = solution["RT"]
		@test rt_solution[1]["Is on"]["GenY"] == [1.0, 1.0]
		@test rt_solution[2]["Is on"]["GenY"] == [1.0, 1.0]
		@test rt_solution[3]["Is on"]["GenY"] == [1.0, 1.0]
		@test rt_solution[4]["Is on"]["GenY"] == [1.0]
		@test length(lmps_rt) == 4
	end
end
