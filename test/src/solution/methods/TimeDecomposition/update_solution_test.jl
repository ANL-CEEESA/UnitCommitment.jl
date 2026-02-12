# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using UnitCommitment, DataStructures

@testfunction solution_methods_TimeDecomposition_update_solution_test begin
    psuedo_solution = OrderedDict()
    time_increment = 4
    psuedo_sub_solution = OrderedDict(
        "Thermal: Production (MW)" => OrderedDict(
            "g1" => [100.0, 200.0, 300.0, 400.0, 500.0, 600.0],
        ),
        "Thermal: Is on" =>
            OrderedDict("g1" => [1.0, 0.0, 1.0, 1.0, 0.0, 1.0]),
        "Profiled: Production (MW)" => OrderedDict(
            "g1" => [199.0, 299.0, 399.0, 499.0, 599.0, 699.0],
        ),
        "Reserve: Spinning (MW)" => OrderedDict(
            "r1" => OrderedDict(
                "g1" => [31.0, 32.0, 33.0, 34.0, 35.0, 36.0],
            ),
        ),
    )

    # first update should directly copy the first 4 entries of sub solution
    UnitCommitment._update_solution!(
        psuedo_solution,
        psuedo_sub_solution,
        time_increment,
    )
    @test psuedo_solution["Thermal: Production (MW)"]["g1"] ==
          [100.0, 200.0, 300.0, 400.0]
    @test psuedo_solution["Thermal: Is on"]["g1"] == [1.0, 0.0, 1.0, 1.0]
    @test psuedo_solution["Profiled: Production (MW)"]["g1"] ==
          [199.0, 299.0, 399.0, 499.0]
    @test psuedo_solution["Reserve: Spinning (MW)"]["r1"]["g1"] ==
          [31.0, 32.0, 33.0, 34.0]

    # second update should append the first 4 entries of sub solution
    UnitCommitment._update_solution!(
        psuedo_solution,
        psuedo_sub_solution,
        time_increment,
    )
    @test psuedo_solution["Thermal: Production (MW)"]["g1"] ==
          [100.0, 200.0, 300.0, 400.0, 100.0, 200.0, 300.0, 400.0]
    @test psuedo_solution["Thermal: Is on"]["g1"] ==
          [1.0, 0.0, 1.0, 1.0, 1.0, 0.0, 1.0, 1.0]
    @test psuedo_solution["Profiled: Production (MW)"]["g1"] ==
          [199.0, 299.0, 399.0, 499.0, 199.0, 299.0, 399.0, 499.0]
    @test psuedo_solution["Reserve: Spinning (MW)"]["r1"]["g1"] ==
          [31.0, 32.0, 33.0, 34.0, 31.0, 32.0, 33.0, 34.0]
end
