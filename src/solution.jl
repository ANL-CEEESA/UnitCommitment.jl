# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

"""
	solution(model::UnitCommitmentModel)::OrderedDict

Extracts the optimal solution from the UC.jl model. The model must be solved beforehand.

# Example

```julia
model = build_model(instance)
optimize!(model)
solution = solution(model)
```
"""
function solution(model::UnitCommitmentModel)::OrderedDict
    haskey(model.data, :solution) ||
        error("No solution available. Call optimize!(model) first.")
    sol = model.data[:solution]
    return length(sol) == 1 ? first(values(sol)) : sol
end

function _store_solution!(model::UnitCommitmentModel)::Nothing
    instance = model.instance
    sol = OrderedDict(sc.name => OrderedDict() for sc in instance.scenarios)
    for sc in instance.scenarios
        _store_bus_solution!(sol[sc.name], model.inner, sc, instance.time)
    end
    for ext in instance.extensions
        store_solution(sol, model, ext)
    end
    _store_summary!(sol, model)
    model.data[:solution] = sol
    return
end

_total(dict) = sum(sum(ts; init = 0) for ts in values(dict); init = 0)
_per_t(dict, T) = [sum(ts[t] for ts in values(dict); init = 0) for t in 1:T]

function _finalize_summary!(summary::OrderedDict)::Nothing
    for (k, v) in summary
        v isa AbstractFloat || continue
        summary[k] = round(v, digits = 2)
    end
    sort!(summary)
    return
end

function _store_summary!(
    sol::AbstractDict,
    model::UnitCommitmentModel;
    ε = 1e-4,
)::Nothing
    instance = model.instance
    T = instance.time

    for sc in instance.scenarios
        s = sol[sc.name]
        summary = get!(OrderedDict, s, "Summary")

        # Load
        bus_loads = [b.load for b in sc[:bus]]
        system_load = [sum(bl[t] for bl in bus_loads) for t in 1:T]
        summary["Bus: System peak load (MW)"] = maximum(system_load)
        summary["Bus: System minimum load (MW)"] = minimum(system_load)

        curtail_per_t = _per_t(s["Bus: Load curtail (MW)"], T)
        total_curtail = sum(curtail_per_t)
        summary["Bus: Total load curtailment (MW)"] = total_curtail
        summary["Bus: Peak load curtailment (MW)"] = maximum(curtail_per_t)

        # Solver
        inner = model.inner
        summary["Solver: Objective value (\$)"] = JuMP.objective_value(inner)
        summary["Solver: Has load curtailment?"] = total_curtail > ε
        summary["Solver: Termination status"] =
            string(JuMP.termination_status(inner))
        summary["Solver: Solve time (s)"] = JuMP.solve_time(inner)
        try
            summary["Solver: Optimality gap (%)"] = JuMP.relative_gap(inner)
            summary["Solver: Objective bound"] = JuMP.objective_bound(inner)
        catch err
            err isa MathOptInterface.GetAttributeNotAllowed || rethrow()
        end

        # Branch overflow flag
        if haskey(s, "Branch: Overflow (MW)")
            overflow = s["Branch: Overflow (MW)"]
            has_overflow =
                any(any(abs(v) > ε for v in ts) for ts in values(overflow))
            summary["Solver: Has branch overflow?"] = has_overflow
        end

        # Reserve shortfall flag
        if haskey(s, "Reserve: Shortfall (MW)")
            shortfall = s["Reserve: Shortfall (MW)"]
            has_shortfall =
                any(any(abs(v) > ε for v in ts) for ts in values(shortfall))
            summary["Solver: Has reserve shortfall?"] = has_shortfall
        end

        # Total penalty: Load curtailment
        penalty = sc[:power_balance_penalty]
        summary["Total penalty: Load curtailment (\$)"] =
            sum(curtail_per_t[t] * penalty[t] for t in 1:T)

        # Reserve shortfall penalty
        if haskey(s, "Reserve: Shortfall (MW)") && haskey(sc, :reserves)
            shortfall = s["Reserve: Shortfall (MW)"]
            summary["Total penalty: Reserve shortfall (\$)"] = sum(
                sum(shortfall[r.name][t] * r.shortfall_penalty for t in 1:T) for r in sc[:reserves];
                init = 0,
            )
            summary["Reserve: Peak shortfall (MW)"] = maximum(
                maximum(shortfall[r.name]) for r in sc[:reserves];
                init = 0,
            )
        end

        _finalize_summary!(summary)
    end
    return
end

export solution
