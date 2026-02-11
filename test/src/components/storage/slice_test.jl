# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using UnitCommitment

@testfunction components_storage_slice_test begin
    instance = UnitCommitment.read(fixture("case14-storage.json.gz"))
    modified = UnitCommitment.slice(instance, 2:4)
    sc = modified.scenarios[1]

    # su1: uniform time-series
    su1 = sc[:storage_by_name]["su1"]
    @test su1.min_level == [0.0, 0.0, 0.0]
    @test su1.max_level == [100.0, 100.0, 100.0]
    @test su1.simultaneous_charge_and_discharge == [true, true, true]
    @test su1.charge_cost == [2.0, 2.0, 2.0]
    @test su1.discharge_cost == [2.5, 2.5, 2.5]
    @test su1.charge_efficiency == [1.0, 1.0, 1.0]
    @test su1.discharge_efficiency == [1.0, 1.0, 1.0]
    @test su1.loss_factor == [0.0, 0.0, 0.0]
    @test su1.min_charge_rate == [0.0, 0.0, 0.0]
    @test su1.max_charge_rate == [10.0, 10.0, 10.0]
    @test su1.min_discharge_rate == [0.0, 0.0, 0.0]
    @test su1.max_discharge_rate == [8.0, 8.0, 8.0]

    # su3: time-varying values (most interesting for slicing)
    su3 = sc[:storage_by_name]["su3"]
    @test su3.min_level == [11.0, 12.0, 13.0]
    @test su3.max_level == [110.0, 120.0, 130.0]
    @test su3.charge_cost == [2.1, 2.2, 2.3]
    @test su3.discharge_cost == [1.1, 1.2, 1.3]
    @test su3.charge_efficiency == [0.81, 0.82, 0.82]
    @test su3.discharge_efficiency == [0.86, 0.87, 0.88]
    @test su3.min_charge_rate == [5.1, 5.2, 5.3]
    @test su3.max_charge_rate == [10.1, 10.2, 10.3]
    @test su3.min_discharge_rate == [4.1, 4.2, 4.3]
    @test su3.max_discharge_rate == [8.1, 8.2, 8.3]

    # su4: time-varying simultaneous flag
    su4 = sc[:storage_by_name]["su4"]
    @test su4.simultaneous_charge_and_discharge == [false, true, true]
end
