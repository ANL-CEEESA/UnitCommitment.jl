# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

function store_solution(
    sol::AbstractDict,
    model::UnitCommitmentModel,
    ::WanHob2016.FlexirampExt,
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
                    ) for t in 1:(T-1)
                ] for g in r.thermal_units
            ) for r in sc[:flexiramp_reserves]
        )

        sol[sc.name]["Flexiramp: Down (MW)"] = OrderedDict(
            r.name => OrderedDict(
                g.name => [
                    round(
                        value(inner[:dwflexiramp][sc.name, r.name, g.name, t]),
                        digits = 5,
                    ) for t in 1:(T-1)
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
                ) for t in 1:(T-1)
            ] for r in sc[:flexiramp_reserves]
        )

        sol[sc.name]["Flexiramp: Down shortfall (MW)"] = OrderedDict(
            r.name => [
                round(
                    value(inner[:dwflexiramp_shortfall][sc.name, r.name, t]),
                    digits = 5,
                ) for t in 1:(T-1)
            ] for r in sc[:flexiramp_reserves]
        )
        summary = sol[sc.name]["Summary"]
        peak_up = maximum(
            maximum(ts) for
            ts in values(sol[sc.name]["Flexiramp: Up shortfall (MW)"])
        )
        peak_dw = maximum(
            maximum(ts) for
            ts in values(sol[sc.name]["Flexiramp: Down shortfall (MW)"])
        )
        summary["Flexiramp: Peak up shortfall (MW)"] = peak_up
        summary["Flexiramp: Peak down shortfall (MW)"] = peak_dw
        summary["Flexiramp: Has shortfall?"] = peak_up > 1e-3 || peak_dw > 1e-3
    end
    return
end
