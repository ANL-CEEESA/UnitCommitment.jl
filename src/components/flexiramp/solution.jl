# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

function store_solution(
    sol::AbstractDict,
    model::UnitCommitmentModel,
    ::FlexirampExt,
)::Nothing
    instance = model.instance
    T = instance.time
    inner = model.inner
    for sc in instance.scenarios
        haskey(sc, :flexiramp_reserves) || continue
        isempty(sc[:flexiramp_reserves]) && continue

        sol[sc.name]["Flexiramp: Up (MW)"] = OrderedDict(
            r.name => OrderedDict(
                g.name => [
                    round(
                        value(inner[:upflexiramp][sc.name, r.name, g.name, t]),
                        digits = 5,
                    ) for t in 1:T
                ] for g in r.thermal_units
            ) for r in sc[:flexiramp_reserves]
        )

        sol[sc.name]["Flexiramp: Down (MW)"] = OrderedDict(
            r.name => OrderedDict(
                g.name => [
                    round(
                        value(inner[:dwflexiramp][sc.name, r.name, g.name, t]),
                        digits = 5,
                    ) for t in 1:T
                ] for g in r.thermal_units
            ) for r in sc[:flexiramp_reserves]
        )

        # Collect generators with mfg variables
        seen = Set{String}()
        mfg_generators = ThermalUnit[]
        for r in sc[:flexiramp_reserves], g in r.thermal_units
            if g.name ∉ seen
                push!(seen, g.name)
                push!(mfg_generators, g)
            end
        end

        sol[sc.name]["Flexiramp: MFG (MW)"] = OrderedDict(
            g.name => [
                round(value(inner[:mfg][sc.name, g.name, t]), digits = 5) for t in 1:T
            ] for g in mfg_generators
        )

        sol[sc.name]["Flexiramp: Up shortfall (MW)"] = OrderedDict(
            r.name => [
                round(
                    value(inner[:upflexiramp_shortfall][sc.name, r.name, t]),
                    digits = 5,
                ) for t in 1:T
            ] for r in sc[:flexiramp_reserves]
        )

        sol[sc.name]["Flexiramp: Down shortfall (MW)"] = OrderedDict(
            r.name => [
                round(
                    value(inner[:dwflexiramp_shortfall][sc.name, r.name, t]),
                    digits = 5,
                ) for t in 1:T
            ] for r in sc[:flexiramp_reserves]
        )
    end
    return
end
