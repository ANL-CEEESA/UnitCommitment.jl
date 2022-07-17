# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using JuMP, MathOptInterface, DataStructures
import JuMP: value, fix, set_name

"""
    function build_model(;
        instance::UnitCommitmentInstance,
        optimizer = nothing,
        formulation = Formulation(),
        variable_names::Bool = false,
    )::JuMP.Model

Build the JuMP model corresponding to the given unit commitment instance.

Arguments
---------

- `instance`:
    the instance.
- `optimizer`:
    the optimizer factory that should be attached to this model (e.g. Cbc.Optimizer).
    If not provided, no optimizer will be attached.
- `formulation`:
    the MIP formulation to use. By default, uses a formulation that combines
    modeling components from different publications that provides good
    performance across a wide variety of instances. An alternative formulation
    may also be provided.
- `variable_names`: 
    if true, set variable and constraint names. Important if the model is going
    to be exported to an MPS file. For large models, this can take significant
    time, so it's disabled by default.

Examples
--------

```julia
# Read benchmark instance
instance = UnitCommitment.read_benchmark("matpower/case118/2017-02-01")

# Construct model (using state-of-the-art defaults)
model = UnitCommitment.build_model(
    instance = instance,
    optimizer = Cbc.Optimizer,
)

# Construct model (using customized formulation)
model = UnitCommitment.build_model(
    instance = instance,
    optimizer = Cbc.Optimizer,
    formulation = Formulation(
        pwl_costs = KnuOstWat2018.PwlCosts(),
        ramping = MorLatRam2013.Ramping(),
        startup_costs = MorLatRam2013.StartupCosts(),
        transmission = ShiftFactorsFormulation(
            isf_cutoff = 0.005,
            lodf_cutoff = 0.001,
        ),
    ),
)
```

"""
function build_model(;
    instance::UnitCommitmentInstance,
    optimizer = nothing,
    formulation = Formulation(),
    variable_names::Bool = false,
)::JuMP.Model
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
