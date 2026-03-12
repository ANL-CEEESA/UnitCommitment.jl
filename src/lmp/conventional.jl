# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using JuMP

function _after_optimize!(
    instance::UnitCommitmentInstance,
    model::UnitCommitmentModel,
    ext::ConventionalLMP,
)::Nothing
    _compute(model, ext)
    return _update_solution(instance, model, ext)
end

function _compute(model::UnitCommitmentModel, ::ConventionalLMP)
    # Create a copy of the model to avoid modifying the original MIP
    lp, ref_map = copy_model(model.inner)
    set_optimizer(lp, model.optimizer)

    # Fix binary variables at their optimal values
    for v in all_variables(model.inner)
        if is_binary(v)
            lp_v = ref_map[v]
            unset_binary(lp_v)
            fix(lp_v, value(v))
        end
    end

    # Relax any remaining integer variables
    relax_integrality(lp)

    # Solve LP and extract duals
    JuMP.optimize!(lp)
    model.data[:lmp] = OrderedDict()
    for (key, val) in model.inner[:eq_net_injection]
        model.data[:lmp][key] = -dual(ref_map[val])
    end
end

function _update_solution(
    instance::UnitCommitmentInstance,
    model::UnitCommitmentModel,
    ::ConventionalLMP,
)::Nothing
    T = instance.time
    sol = model.data[:solution]
    for sc in instance.scenarios
        lmp_total =
            sol[sc.name]["LMP: Total (\$/MWh)"] = OrderedDict(
                b.name =>
                    [model.data[:lmp][sc.name, b.name, t] for t in 1:T] for
                b in sc[:bus]
            )
        sol[sc.name]["LMP: Energy (\$/MWh)"] = OrderedDict(
            b.name => [
                minimum(lmp_total[bb.name][t] for bb in sc[:bus]) for t in 1:T
            ] for b in sc[:bus]
        )
        sol[sc.name]["LMP: Congestion (\$/MWh)"] = OrderedDict(
            b.name => [
                lmp_total[b.name][t] -
                sol[sc.name]["LMP: Energy (\$/MWh)"][b.name][t] for
                t in 1:T
            ] for b in sc[:bus]
        )
        if haskey(sc, :thermal)
            thermal_units = sc[:thermal]
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
                    sol[sc.name]["Thermal: Startup cost (\$)"][g.name][t] -
                    sol[sc.name]["Thermal: Shutdown cost (\$)"][g.name][t]
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
            profiled_units = sc[:profiled]
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
            b in sc[:bus]
        )

        if "Price-sensitive load: Demand served (MW)" in keys(sol[sc.name])
            ps_loads = sc[:psload]
            sol[sc.name]["Price-sensitive load: Expense (\$)"] = OrderedDict(
                ps.name => [
                    sol[sc.name]["Price-sensitive load: Demand served (MW)"][ps.name][t] *
                    lmp_total[ps.bus.name][t] for t in 1:T
                ] for ps in ps_loads
            )
        end

        s = sol[sc.name]
        summary = get!(OrderedDict, s, "Summary")

        # LMP summary
        bus_loads = [b.load for b in sc[:bus]]
        total_load = sum(sum(bl) for bl in bus_loads)

        # Load-weighted average LMP
        if total_load > 0
            weighted_lmp = sum(
                lmp_total[b.name][t] * b.load[t]
                for b in sc[:bus] for t in 1:T
            )
            summary["LMP: Average (\$/MWh)"] = weighted_lmp / total_load
        end

        # Peak and minimum LMP
        all_lmps = [lmp_total[b.name][t] for b in sc[:bus] for t in 1:T]
        summary["LMP: Peak (\$/MWh)"] = maximum(all_lmps)
        summary["LMP: Minimum (\$/MWh)"] = minimum(all_lmps)

        # Load expense summary
        summary["Bus: Total fixed load expense (\$)"] =
            _total(sol[sc.name]["Bus: Fixed load expense (\$)"])

        # PS load expense summary
        if haskey(s, "Price-sensitive load: Expense (\$)")
            summary["Price-sensitive load: Total expense (\$)"] =
                _total(s["Price-sensitive load: Expense (\$)"])
        end

        if "Virtual: Cleared (MW)" in keys(sol[sc.name])
            virtuals = sc[:virtual]
            sol[sc.name]["Virtual: Revenue (\$)"] = OrderedDict(
                vt.name => begin
                    cleared = sol[sc.name]["Virtual: Cleared (MW)"][vt.name]
                    if vt.type == :inc
                        [
                            cleared[t] * lmp_total[vt.bus_source.name][t] for
                            t in 1:T
                        ]
                    elseif vt.type == :dec
                        [-cleared[t] * lmp_total[vt.bus_sink.name][t] for t in 1:T]
                    else  # :utc
                        [
                            cleared[t] * (
                                lmp_total[vt.bus_source.name][t] -
                                lmp_total[vt.bus_sink.name][t]
                            ) for t in 1:T
                        ]
                    end
                end for vt in virtuals
            )

            # Virtual revenue summary
            summary["Virtual: Total revenue (\$)"] =
                _total(sol[sc.name]["Virtual: Revenue (\$)"])
        end

        # Round all floating-point LMP summary values
        for (k, v) in summary
            v isa AbstractFloat || continue
            summary[k] = round(v, digits = 2)
        end
    end
    return
end
