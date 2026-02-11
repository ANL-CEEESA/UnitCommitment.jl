# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using UnitCommitment

@testfunction components_storage_read_test begin
    instance = UnitCommitment.read(fixture("case14-storage.json.gz"))
    sc = instance.scenarios[1]
    @test length(sc[:storage]) == 4

    su1 = sc[:storage][1]
    @test su1.name == "su1"
    @test su1.bus.name == "b2"
    @test su1.min_level == [0.0 for t in 1:4]
    @test su1.max_level == [100.0 for t in 1:4]
    @test su1.simultaneous_charge_and_discharge == [true for t in 1:4]
    @test su1.charge_cost == [2.0 for t in 1:4]
    @test su1.discharge_cost == [2.5 for t in 1:4]
    @test su1.charge_efficiency == [1.0 for t in 1:4]
    @test su1.discharge_efficiency == [1.0 for t in 1:4]
    @test su1.loss_factor == [0.0 for t in 1:4]
    @test su1.min_charge_rate == [0.0 for t in 1:4]
    @test su1.max_charge_rate == [10.0 for t in 1:4]
    @test su1.min_discharge_rate == [0.0 for t in 1:4]
    @test su1.max_discharge_rate == [8.0 for t in 1:4]
    @test su1.initial_level == 0.0
    @test su1.min_ending_level == 0.0
    @test su1.max_ending_level == 100.0
    @test sc[:storage_by_name]["su1"].name == "su1"

    su2 = sc[:storage][2]
    @test su2.name == "su2"
    @test su2.bus.name == "b2"
    @test su2.min_level == [10.0 for t in 1:4]
    @test su2.simultaneous_charge_and_discharge == [false for t in 1:4]
    @test su2.charge_cost == [3.0 for t in 1:4]
    @test su2.discharge_cost == [3.5 for t in 1:4]
    @test su2.charge_efficiency == [0.8 for t in 1:4]
    @test su2.discharge_efficiency == [0.85 for t in 1:4]
    @test su2.loss_factor == [0.01 for t in 1:4]
    @test su2.min_charge_rate == [5.0 for t in 1:4]
    @test su2.min_discharge_rate == [2.0 for t in 1:4]
    @test su2.initial_level == 70.0
    @test su2.min_ending_level == 80.0
    @test su2.max_ending_level == 85.0
    @test sc[:storage_by_name]["su2"].name == "su2"

    su3 = sc[:storage][3]
    @test su3.bus.name == "b9"
    @test su3.min_level == [10.0, 11.0, 12.0, 13.0]
    @test su3.max_level == [100.0, 110.0, 120.0, 130.0]
    @test su3.charge_cost == [2.0, 2.1, 2.2, 2.3]
    @test su3.discharge_cost == [1.0, 1.1, 1.2, 1.3]
    @test su3.charge_efficiency == [0.8, 0.81, 0.82, 0.82]
    @test su3.discharge_efficiency == [0.85, 0.86, 0.87, 0.88]
    @test su3.min_charge_rate == [5.0, 5.1, 5.2, 5.3]
    @test su3.max_charge_rate == [10.0, 10.1, 10.2, 10.3]
    @test su3.min_discharge_rate == [4.0, 4.1, 4.2, 4.3]
    @test su3.max_discharge_rate == [8.0, 8.1, 8.2, 8.3]

    su4 = sc[:storage][4]
    @test su4.simultaneous_charge_and_discharge == [false, false, true, true]
end
