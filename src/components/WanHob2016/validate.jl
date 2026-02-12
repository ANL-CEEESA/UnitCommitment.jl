# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using Printf

function validate(
    instance::UnitCommitmentInstance,
    solution::AbstractDict,
    ::WanHob2016.FlexirampExt,
)::Int
    err_count = 0
    tol = 0.01
    for sc in instance.scenarios
        haskey(sc, :flexiramp_reserves) || continue
        for r in sc[:flexiramp_reserves]
            for t in 1:instance.time
                up_provided = sum(
                    solution[sc.name]["Flexiramp: Up (MW)"][r.name][g.name][t]
                    for g in r.thermal_units
                )
                up_shortfall =
                    solution[sc.name]["Flexiramp: Up shortfall (MW)"][r.name][t]
                if up_provided + up_shortfall < r.amount[t] - tol
                    @error @sprintf(
                        "Insufficient up flexiramp %s at time %d (%.2f + %.2f < %.2f)",
                        r.name,
                        t,
                        up_provided,
                        up_shortfall,
                        r.amount[t],
                    )
                    err_count += 1
                end

                dw_provided = sum(
                    solution[sc.name]["Flexiramp: Down (MW)"][r.name][g.name][t]
                    for g in r.thermal_units
                )
                dw_shortfall =
                    solution[sc.name]["Flexiramp: Down shortfall (MW)"][r.name][t]
                if dw_provided + dw_shortfall < r.amount[t] - tol
                    @error @sprintf(
                        "Insufficient down flexiramp %s at time %d (%.2f + %.2f < %.2f)",
                        r.name,
                        t,
                        dw_provided,
                        dw_shortfall,
                        r.amount[t],
                    )
                    err_count += 1
                end
            end
        end
    end
    return err_count
end
