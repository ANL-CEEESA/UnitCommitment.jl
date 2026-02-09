# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

"""
	solution(model::JuMP.Model)::OrderedDict

Extracts the optimal solution from the UC.jl model. The model must be solved beforehand.

# Example

```julia
UnitCommitment.optimize!(model)
solution = UnitCommitment.solution(model)
```
"""
function solution(model::JuMP.Model)::OrderedDict
    instance = model[:instance]
    sol = model.ext[:ucjl][:solution]

    if length(instance.scenarios) == 1
        sol = first(values(sol))
    end

    return sol
end

function _store_line_solution!(sol::OrderedDict, model::JuMP.Model, sc, T::Int)
    non_slack_buses = [b for b in sc.buses if b.offset > 0]
    net_injection = model[:net_injection]
    net_injection_values = [
        value(net_injection[sc.name, b.name, t]) for b in non_slack_buses,
        t in 1:T
    ]
    flows = sc.isf * net_injection_values

    sol["Line: Flow (MW)"] = OrderedDict(
        line.name =>
            [round(flows[line.offset, t], digits = 5) for t in 1:T] for
        line in sc.lines
    )
    sol["Line: Overflow (MW)"] =
        _timeseries(model, :overflow, sc.lines, T, sc = sc)
    sol["Line: Overflow penalty (\$)"] = OrderedDict(
        line.name => [
            value(model[:overflow][sc.name, line.name, t]) *
            line.flow_limit_penalty[t] for t in 1:T
        ] for line in sc.lines
    )
    sol["Line: Utilization (%)"] = OrderedDict(
        line.name => [
            round(
                100.0 * abs(flows[line.offset, t]) / line.normal_flow_limit[t],
                digits = 2,
            ) for t in 1:T
        ] for line in sc.lines
    )
    sol["Line: Investment cost (\$)"] = OrderedDict(
        line.name => [
            (
                value(model[:invest_line][line.name, t]) -
                value(model[:invest_line][line.name, t-1])
            ) * line.invest[t] for t in 1:T
        ] for line in sc.lines if line.invest[1] > 0.0
    )
    sol["Line: Investment status"] = OrderedDict(
        line.name =>
            [value(model[:invest_line][line.name, t]) for t in 1:T] for
        line in sc.lines if line.invest[1] > 0.0
    )
    return
end

function _store_solution!(model::JuMP.Model)::Nothing
    instance, T = model[:instance], model[:instance].time
    sol = OrderedDict()

    for sc in instance.scenarios
        sol[sc.name] = OrderedDict()
        _store_bus_solution!(sol[sc.name], model, sc, T)
        _store_line_solution!(sol[sc.name], model, sc, T)
    end

    for ext in instance.extensions
        store_solution(sol, model, ext)
    end

    model.ext[:ucjl][:solution] = sol
    return
end
