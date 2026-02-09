# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using JuMP

function _after_optimize!(model::JuMP.Model, ::ConventionalLMP)::Nothing
    # Record binary variables and their optimal values
    binary_vars = [(v, value(v)) for v in all_variables(model) if is_binary(v)]

    # Fix binary variables and remove binary constraint
    for (v, val) in binary_vars
        unset_binary(v)
        fix(v, val)
    end

    # Relax any remaining integer variables
    undo_relax = relax_integrality(model)

    # Solve LP and extract duals
    JuMP.optimize!(model)

    model.ext[:lmp_values] = OrderedDict()
    for (key, val) in model[:eq_net_injection]
        model.ext[:lmp_values][key] = dual(val)
    end

    # Restore model state
    undo_relax()
    for (v, _) in binary_vars
        unfix(v)
        set_binary(v)
    end
end

function store_solution(
    sol::AbstractDict,
    model::JuMP.Model,
    ::ConventionalLMP,
)::Nothing
    instance = model[:instance]
    T = instance.time
    for sc in instance.scenarios
        lmp_total =
            sol[sc.name]["LMP: Total (\$/MWh)"] = OrderedDict(
                b.name => [
                    model.ext[:lmp_values][sc.name, b.name, t] for t in 1:T
                ] for b in sc.data[:bus]
            )
        sol[sc.name]["LMP: Energy (\$/MWh)"] = OrderedDict(
            b.name => [
                minimum(lmp_total[bb.name][t] for bb in sc.data[:bus]) for t in 1:T
            ] for b in sc.buses
        )
        sol[sc.name]["LMP: Congestion (\$/MWh)"] = OrderedDict(
            b.name => [
                lmp_total[b.name][t] -
                sol[sc.name]["LMP: Energy (\$/MWh)"][b.name][t] for
                t in 1:T
            ] for b in sc.buses
        )
        if haskey(sc.data, :thermal)
            thermal_units = sc.data[:thermal]
            sol[sc.name]["Thermal: Gross revenue (\$)"] = OrderedDict(
                g.name => [
                    sol[sc.name]["Thermal: Production (MW)"][g.name][t] *
                    lmp_total[g.bus.name][t] for t in 1:T
                ] for g in thermal_units
            )
            sol[sc.name]["Thermal: Net revenue (\$)"] = OrderedDict(
                g.name => [
                    sol[sc.name]["Thermal: Gross revenue (\$)"][g.name][t] -
                    sol[sc.name]["Thermal: Production cost (\$)"][g.name][t] -
                    sol[sc.name]["Thermal: Startup cost (\$)"][g.name][t]
                    for t in 1:T
                ] for g in thermal_units
            )
            sol[sc.name]["Thermal: Uplift payment (\$)"] = OrderedDict(
                g.name => max(
                    0.0,
                    -sum(sol[sc.name]["Thermal: Net revenue (\$)"][g.name]),
                ) for g in thermal_units
            )
        end

        if "Profiled: Production (MW)" in keys(sol[sc.name])
            profiled_units = sc.data[:profiled]
            sol[sc.name]["Profiled: Gross revenue (\$)"] = OrderedDict(
                pu.name => [
                    sol[sc.name]["Profiled: Production (MW)"][pu.name][t] *
                    lmp_total[pu.bus.name][t] for t in 1:T
                ] for pu in profiled_units
            )
            sol[sc.name]["Profiled: Net revenue (\$)"] = OrderedDict(
                pu.name => [
                    sol[sc.name]["Profiled: Gross revenue (\$)"][pu.name][t] -
                    sol[sc.name]["Profiled: Production cost (\$)"][pu.name][t]
                    for t in 1:T
                ] for pu in profiled_units
            )
            sol[sc.name]["Profiled: Uplift payment (\$)"] = OrderedDict(
                pu.name => max(
                    0.0,
                    -sum(sol[sc.name]["Profiled: Net revenue (\$)"][pu.name]),
                ) for pu in profiled_units
            )
        end
        sol[sc.name]["Bus: Fixed load expense (\$)"] = OrderedDict(
            b.name => [b.load[t] * lmp_total[b.name][t] for t in 1:T] for
            b in sc.buses
        )

        if "Price-sensitive load: Demand served (MW)" in keys(sol[sc.name])
            ps_loads = sc.data[:psload]
            sol[sc.name]["Price-sensitive load: Expense (\$)"] = OrderedDict(
                ps.name => [
                    sol[sc.name]["Price-sensitive load: Demand served (MW)"][ps.name][t] *
                    lmp_total[ps.bus.name][t] for t in 1:T
                ] for ps in ps_loads
            )
        end
    end
    return
end
