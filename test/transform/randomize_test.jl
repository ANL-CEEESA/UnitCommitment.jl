# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using UnitCommitment, Cbc, JuMP

_get_instance() = UnitCommitment.read_benchmark("matpower/case118/2017-02-01")
_total_load(instance) = sum(b.load[1] for b in instance.buses)

@testset "randomize_unit_costs!" begin
    instance = _get_instance()
    unit = instance.units[10]
    prev_min_power_cost = unit.min_power_cost
    prev_prod_cost = unit.cost_segments[1].cost
    prev_startup_cost = unit.startup_categories[1].cost
    randomize_unit_costs!(instance)
    @test prev_min_power_cost != unit.min_power_cost
    @test prev_prod_cost != unit.cost_segments[1].cost
    @test prev_startup_cost != unit.startup_categories[1].cost
end

@testset "randomize_load_distribution!" begin
    instance = _get_instance()
    bus = instance.buses[1]
    prev_load = instance.buses[1].load[1]
    prev_total_load = _total_load(instance)
    randomize_load_distribution!(instance)
    curr_total_load = _total_load(instance)
    @test prev_load != instance.buses[1].load[1]
    @test abs(prev_total_load - curr_total_load) < 1e-3
end

@testset "randomize_peak_load!" begin
    instance = _get_instance()
    bus = instance.buses[1]
    prev_total_load = _total_load(instance)
    prev_share = bus.load[1] / prev_total_load
    randomize_peak_load!(instance)
    curr_total_load = _total_load(instance)
    curr_share = bus.load[1] / prev_total_load
    @test curr_total_load != prev_total_load
    @test abs(curr_share - prev_share) < 1e-3
end
