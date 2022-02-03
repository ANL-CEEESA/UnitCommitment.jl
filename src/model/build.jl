# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using JuMP, MathOptInterface, DataStructures
import JuMP: value, fix, set_name

"""
    function build_model(;
        instance::UnitCommitmentInstance,
        optimizer = nothing,
        variable_names::Bool = false,
    )::JuMP.Model

Build the JuMP model corresponding to the given unit commitment instance.

Arguments
=========
- `instance`:
    the instance.
- `optimizer`:
    the optimizer factory that should be attached to this model (e.g. Cbc.Optimizer).
    If not provided, no optimizer will be attached.
- `variable_names`: 
    If true, set variable and constraint names. Important if the model is going
    to be exported to an MPS file. For large models, this can take significant
    time, so it's disabled by default.
"""
function build_model(;
    instance::UnitCommitmentInstance,
    optimizer = nothing,
    formulation = Formulation(),
    variable_names::Bool = false,
)::JuMP.Model
    if formulation.ramping ==WanHob2016.Ramping() && instance.reserves.spinning!=zeros(instance.time)
        error("Spinning reserves are not supported by the WanHob2016 ramping formulation")
    end
    @show formulation.ramping
    if formulation.ramping !== WanHob2016.Ramping() && (instance.reserves.upflexiramp!=zeros(instance.time) || instance.reserves.dwflexiramp!=zeros(instance.time))
        error("Flexiramp is supported only by the WanHob2016 ramping formulation")
    end

    @info "Building model..."
    time_model = @elapsed begin
        model = Model()
        if optimizer !== nothing
            set_optimizer(model, optimizer)
        end
        model[:obj] = AffExpr()
        model[:instance] = instance
        _setup_transmission(model, formulation.transmission)
        for l in instance.lines
            _add_transmission_line!(model, l, formulation.transmission)
        end
        for b in instance.buses
            _add_bus!(model, b)
        end
        for g in instance.units
            _add_unit!(model, g, formulation)
        end
        for ps in instance.price_sensitive_loads
            _add_price_sensitive_load!(model, ps)
        end
        _add_system_wide_eqs!(model)
        @objective(model, Min, model[:obj])
    end
    @info @sprintf("Built model in %.2f seconds", time_model)
    if variable_names
        _set_names!(model)
    end
    return model
end
