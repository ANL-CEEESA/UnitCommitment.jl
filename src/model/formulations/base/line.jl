# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

function _add_transmission_line!(
    model::JuMP.Model,
    lm::TransmissionLine,
    f::ShiftFactorsFormulation,
    sc::UnitCommitmentScenario,
)::Nothing
    overflow = _init(model, :overflow)
    for t in 1:model[:instance].time
        overflow[sc.name, lm.name, t] = @variable(model, lower_bound = 0)
        add_to_expression!(
            model[:obj],
            overflow[sc.name, lm.name, t],
            lm.flow_limit_penalty[t] * sc.probability,
        )
    end
    return
end

function _setup_transmission(
    formulation::ShiftFactorsFormulation,
    sc::UnitCommitmentScenario,
)::Nothing
    isf = formulation.precomputed_isf
    lodf = formulation.precomputed_lodf
    if length(sc.buses) == 1
        isf = zeros(0, 0)
        lodf = zeros(0, 0)
    elseif isf === nothing
        @info "Computing injection shift factors..."
        time_isf = @elapsed begin
            isf = UnitCommitment._injection_shift_factors(
                buses = sc.buses,
                lines = sc.lines,
            )
        end
        @info @sprintf("Computed ISF in %.2f seconds", time_isf)
        @info "Computing line outage factors..."
        time_lodf = @elapsed begin
            lodf = UnitCommitment._line_outage_factors(
                buses = sc.buses,
                lines = sc.lines,
                isf = isf,
            )
        end
        @info @sprintf("Computed LODF in %.2f seconds", time_lodf)
        @info @sprintf(
            "Applying PTDF and LODF cutoffs (%.5f, %.5f)",
            formulation.isf_cutoff,
            formulation.lodf_cutoff
        )
        isf[abs.(isf).<formulation.isf_cutoff] .= 0
        lodf[abs.(lodf).<formulation.lodf_cutoff] .= 0
    end
    sc.isf = isf
    sc.lodf = lodf
    return
end
