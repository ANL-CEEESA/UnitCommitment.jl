# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using UnitCommitment, HiGHS, JuMP

function solve_conventional_testcase(path::String)
    instance = UnitCommitment.read(
        path,
        extensions=[
            UnitCommitment.ConventionalLMP(),
        ]
    )
    model = UnitCommitment.build_model(
        instance = instance,
        optimizer = optimizer_with_attributes(
            HiGHS.Optimizer,
            "log_to_console" => false,
        ),
        variable_names = true,
    )
    JuMP.set_silent(model)
    UnitCommitment.optimize!(model)
    return UnitCommitment.solution(model)
end

function lmp_conventional_test()
    @testset "conventional" begin
        # Instance 1: No congestion, inframarginal rent
        # Ga ($30/MWh, 50 MW max) produces at capacity, Gb ($60/MWh) is marginal
        # LMP = $60 everywhere; Ga earns positive net revenue
        path = fixture("lmp_simple_test_1.json")
        sol = solve_conventional_testcase(path)
        lmp = sol["LMP: Total (\$/MWh)"]
        energy = sol["LMP: Energy (\$/MWh)"]
        congestion = sol["LMP: Congestion (\$/MWh)"]
        @test lmp["A", 1] == 60.0
        @test lmp["B", 1] == 60.0
        @test energy["A", 1] == 60.0
        @test energy["B", 1] == 60.0
        @test congestion["A", 1] == 0.0
        @test congestion["B", 1] == 0.0
        @test sol["Thermal: Gross revenue (\$)"]["Ga"] == [3000.0]
        @test sol["Thermal: Gross revenue (\$)"]["Gb"] == [3000.0]
        @test sol["Thermal: Net revenue (\$)"]["Ga"] == [1500.0]
        @test sol["Thermal: Net revenue (\$)"]["Gb"] == [0.0]
        @test sol["Thermal: Uplift payment (\$)"]["Ga"] == 0.0
        @test sol["Thermal: Uplift payment (\$)"]["Gb"] == 0.0
        @test sol["Bus: Fixed load expense (\$)"]["A"] == [0.0]
        @test sol["Bus: Fixed load expense (\$)"]["B"] == [6000.0]
        @test isempty(sol["Price-sensitive load: Expense (\$)"])

        # Instance 2: Congestion, uplift from startup cost
        # Gb ($60/MWh) must start up to serve 10 MW behind congestion,
        # but its $1000 startup cost exceeds its market revenue
        path = fixture("lmp_simple_test_2.json")
        sol = solve_conventional_testcase(path)
        lmp = sol["LMP: Total (\$/MWh)"]
        energy = sol["LMP: Energy (\$/MWh)"]
        congestion = sol["LMP: Congestion (\$/MWh)"]
        @test lmp["A", 1] == 50.0
        @test lmp["B", 1] == 60.0
        @test energy["A", 1] == 50.0
        @test energy["B", 1] == 50.0
        @test congestion["A", 1] == 0.0
        @test congestion["B", 1] == 10.0
        @test sol["Thermal: Gross revenue (\$)"]["Ga"] == [5000.0]
        @test sol["Thermal: Gross revenue (\$)"]["Gb"] == [600.0]
        @test sol["Thermal: Net revenue (\$)"]["Ga"] == [0.0]
        @test sol["Thermal: Net revenue (\$)"]["Gb"] == [-1000.0]
        @test sol["Thermal: Uplift payment (\$)"]["Ga"] == 0.0
        @test sol["Thermal: Uplift payment (\$)"]["Gb"] == 1000.0
        @test sol["Bus: Fixed load expense (\$)"]["A"] == [0.0]
        @test sol["Bus: Fixed load expense (\$)"]["B"] == [6600.0]
        @test isempty(sol["Price-sensitive load: Expense (\$)"])

        # Instance 3: Profiled unit with positive net revenue
        # Gp (profiled, $40/MWh) at bus B earns revenue at LMP of $70/MWh
        path = fixture("lmp_simple_test_3.json")
        sol = solve_conventional_testcase(path)
        lmp = sol["LMP: Total (\$/MWh)"]
        energy = sol["LMP: Energy (\$/MWh)"]
        congestion = sol["LMP: Congestion (\$/MWh)"]
        @test lmp["A", 1] == 50.0
        @test lmp["B", 1] == 70.0
        @test lmp["C", 1] == 100.0
        @test energy["A", 1] == 50.0
        @test energy["B", 1] == 50.0
        @test energy["C", 1] == 50.0
        @test congestion["A", 1] == 0.0
        @test congestion["B", 1] == 20.0
        @test congestion["C", 1] == 50.0
        @test sol["Profiled: Gross revenue (\$)"]["Gp"] == [1400.0]
        @test sol["Profiled: Net revenue (\$)"]["Gp"] == [600.0]
        @test sol["Profiled: Uplift payment (\$)"]["Gp"] == 0.0
        @test sol["Bus: Fixed load expense (\$)"]["A"] == [0.0]
        @test sol["Bus: Fixed load expense (\$)"]["B"] == [3500.0]
        @test sol["Bus: Fixed load expense (\$)"]["C"] == [10000.0]
        @test isempty(sol["Price-sensitive load: Expense (\$)"])

        # Instance 4: Profiled unit with uplift
        # Gp (profiled, $200/MWh, must produce 20 MW) at bus C where LMP = $60
        path = fixture("lmp_simple_test_4.json")
        sol = solve_conventional_testcase(path)
        lmp = sol["LMP: Total (\$/MWh)"]
        energy = sol["LMP: Energy (\$/MWh)"]
        congestion = sol["LMP: Congestion (\$/MWh)"]
        @test lmp["A", 1] == 50.0
        @test lmp["B", 1] == 70.0
        @test lmp["C", 1] == 60.0
        @test energy["A", 1] == 50.0
        @test energy["B", 1] == 50.0
        @test energy["C", 1] == 50.0
        @test congestion["A", 1] == 0.0
        @test congestion["B", 1] == 20.0
        @test congestion["C", 1] == 10.0
        @test sol["Profiled: Gross revenue (\$)"]["Gp"] == [1200.0]
        @test sol["Profiled: Net revenue (\$)"]["Gp"] == [-2800.0]
        @test sol["Profiled: Uplift payment (\$)"]["Gp"] == 2800.0
        @test sol["Bus: Fixed load expense (\$)"]["A"] == [0.0]
        @test sol["Bus: Fixed load expense (\$)"]["B"] == [3500.0]
        @test sol["Bus: Fixed load expense (\$)"]["C"] == [6000.0]
        @test isempty(sol["Price-sensitive load: Expense (\$)"])
    end
end
