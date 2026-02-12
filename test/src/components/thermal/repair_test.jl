# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using UnitCommitment, JSON, Logging

function _read_modified(modify!, path)
    json = JSON.parsefile(path)
    modify!(json)
    tmpfile = tempname() * ".json"
    open(tmpfile, "w") do io
        return JSON.print(io, json)
    end
    return UnitCommitment.read(tmpfile, repair = false)
end

@testfunction components_thermal_repair_convex_cost_test begin
    instance = _read_modified(fixture("case14/base.json")) do json
        json["Generators"]["g1"]["Production cost curve (MW)"] = [100, 150, 200]
        return json["Generators"]["g1"]["Production cost curve (\$)"] =
            [10, 25, 30]
    end
    @test_logs (:warn, r"Generator .* has non-convex production cost curve") match_mode =
        :any begin
        @test UnitCommitment.repair!(instance) == 4
    end
end

@testfunction components_thermal_repair_startup_limit_test begin
    instance = _read_modified(fixture("case14/base.json")) do json
        json["Generators"]["g1"]["Production cost curve (MW)"] = [100, 150]
        json["Generators"]["g1"]["Production cost curve (\$)"] = [100, 150]
        return json["Generators"]["g1"]["Startup limit (MW)"] = 80
    end
    @test_logs (
        :warn,
        r"Generator .* has startup limit lower than minimum power",
    ) match_mode = :any begin
        @test UnitCommitment.repair!(instance) == 1
    end
end

@testfunction components_thermal_repair_startup_costs_test begin
    instance = _read_modified(fixture("case14/base.json")) do json
        json["Generators"]["g1"]["Startup costs (\$)"] = [300, 200, 100]
        return json["Generators"]["g1"]["Startup delays (h)"] = [8, 4, 2]
    end
    @test_logs (
        :warn,
        r"Generator .* has (non-increasing startup delays|decreasing startup cost)",
    ) match_mode = :any begin
        @test UnitCommitment.repair!(instance) == 4
    end
end
