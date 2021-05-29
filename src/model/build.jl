# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using JuMP, MathOptInterface, DataStructures
import JuMP: value, fix, set_name

"""
    function build_model(;
        instance::UnitCommitmentInstance,
        isf::Union{Matrix{Float64},Nothing} = nothing,
        lodf::Union{Matrix{Float64},Nothing} = nothing,
        isf_cutoff::Float64 = 0.005,
        lodf_cutoff::Float64 = 0.001,
        optimizer = nothing,
        variable_names::Bool = false,
    )::JuMP.Model

Build the JuMP model corresponding to the given unit commitment instance.

Arguments
=========
- `instance::UnitCommitmentInstance`:
    the instance.
- `isf::Union{Matrix{Float64},Nothing} = nothing`:
    the injection shift factors matrix. If not provided, it will be computed.
- `lodf::Union{Matrix{Float64},Nothing} = nothing`: 
    the line outage distribution factors matrix. If not provided, it will be
    computed.
- `isf_cutoff::Float64 = 0.005`: 
    the cutoff that should be applied to the ISF matrix. Entries with magnitude
    smaller than this value will be set to zero.
- `lodf_cutoff::Float64 = 0.001`: 
    the cutoff that should be applied to the LODF matrix. Entries with magnitude
    smaller than this value will be set to zero.
- `optimizer = nothing`:
    the optimizer factory that should be attached to this model (e.g. Cbc.Optimizer).
    If not provided, no optimizer will be attached.
- `variable_names::Bool = false`: 
    If true, set variable and constraint names. Important if the model is going
    to be exported to an MPS file. For large models, this can take significant
    time, so it's disabled by default.

Example
=======
```jldoctest
julia> import Cbc, UnitCommitment
julia> instance = UnitCommitment.read_benchmark("matpower/case118/2017-02-01")
julia> model = UnitCommitment.build_model(
    instance=instance,
    optimizer=Cbc.Optimizer,
    variable_names=true,
)
```
"""
function build_model(;
    instance::UnitCommitmentInstance,
    isf::Union{Matrix{Float64},Nothing} = nothing,
    lodf::Union{Matrix{Float64},Nothing} = nothing,
    isf_cutoff::Float64 = 0.005,
    lodf_cutoff::Float64 = 0.001,
    optimizer = nothing,
    variable_names::Bool = false,
)::JuMP.Model
    if length(instance.buses) == 1
        isf = zeros(0, 0)
        lodf = zeros(0, 0)
    else
        if isf === nothing
            @info "Computing injection shift factors..."
            time_isf = @elapsed begin
                isf = UnitCommitment._injection_shift_factors(
                    lines = instance.lines,
                    buses = instance.buses,
                )
            end
            @info @sprintf("Computed ISF in %.2f seconds", time_isf)
            @info "Computing line outage factors..."
            time_lodf = @elapsed begin
                lodf = UnitCommitment._line_outage_factors(
                    lines = instance.lines,
                    buses = instance.buses,
                    isf = isf,
                )
            end
            @info @sprintf("Computed LODF in %.2f seconds", time_lodf)

            @info @sprintf(
                "Applying PTDF and LODF cutoffs (%.5f, %.5f)",
                isf_cutoff,
                lodf_cutoff
            )
            isf[abs.(isf).<isf_cutoff] .= 0
            lodf[abs.(lodf).<lodf_cutoff] .= 0
        end
    end
    @info "Building model..."
    time_model = @elapsed begin
        model = Model()
        if optimizer !== nothing
            set_optimizer(model, optimizer)
        end
        model[:obj] = AffExpr()
        model[:instance] = instance
        model[:isf] = isf
        model[:lodf] = lodf
        _add_transmission_line!.(model, instance.lines)
        _add_bus!.(model, instance.buses)
        _add_unit!.(model, instance.units)
        _add_price_sensitive_load!.(model, instance.price_sensitive_loads)
        _add_system_wide_eqs!(model)
        @objective(model, Min, model[:obj])
    end
    @info @sprintf("Built model in %.2f seconds", time_model)
    if variable_names
        _set_names!(model)
    end
    return model
end
