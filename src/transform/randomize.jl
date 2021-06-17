# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2021, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using Distributions

function randomize_unit_costs!(
    instance::UnitCommitmentInstance;
    distribution = Uniform(0.95, 1.05),
)::Nothing
    for unit in instance.units
        α = rand(distribution)
        unit.min_power_cost *= α
        for k in unit.cost_segments
            k.cost *= α
        end
        for s in unit.startup_categories
            s.cost *= α
        end
    end
    return
end

function randomize_load_distribution!(
    instance::UnitCommitmentInstance;
    distribution = Uniform(0.90, 1.10),
)::Nothing
    α = rand(distribution, length(instance.buses))
    for t in 1:instance.time
        total = sum(bus.load[t] for bus in instance.buses)
        den = sum(
            bus.load[t] / total * α[i] for
            (i, bus) in enumerate(instance.buses)
        )
        for (i, bus) in enumerate(instance.buses)
            bus.load[t] *= α[i] / den
        end
    end
    return
end

function randomize_peak_load!(
    instance::UnitCommitmentInstance;
    distribution = Uniform(0.925, 1.075),
)::Nothing
    α = rand(distribution)
    for bus in instance.buses
        bus.load *= α
    end
    return
end

export randomize_unit_costs!, randomize_load_distribution!, randomize_peak_load!
