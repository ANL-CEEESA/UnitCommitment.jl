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
        for g in instance.scenarios[1].thermal_units
            _add_unit_commitment!(model, g, formulation)
        end
        for sc in instance.scenarios
            @info "Building scenario $(sc.name) with " *
                  "probability $(sc.probability)"
            _setup_transmission(formulation.transmission, sc)
            for l in sc.lines
                _add_transmission_line!(model, l, formulation.transmission, sc)
            end
            for b in sc.buses
                _add_bus!(model, b, sc)
            end
            for ps in sc.price_sensitive_loads
                _add_price_sensitive_load!(model, ps, sc)
            end
            for g in sc.thermal_units
                _add_unit_dispatch!(model, g, formulation, sc)
            end
            for pu in sc.profiled_units
                _add_profiled_unit!(model, pu, sc)
            end
            for su in sc.storage_units
                _add_storage_unit!(model, su, sc)
            end
            _add_system_wide_eqs!(model, sc)
            for ifc in sc.interfaces
                _add_interface!(model, ifc, formulation.transmission, sc)
            end
        end
        @objective(model, Min, model[:obj])
    end
    @info @sprintf("Built model in %.2f seconds", time_model)
    if variable_names
        _set_names!(model)
    end
    return model
end
