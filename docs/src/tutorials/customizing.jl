# # Model customization

# In the previous tutorial, we used UnitCommitment.jl to solve benchmark and user-provided instances using a default mathematical formulation for the problem. In this tutorial, we will explore how to customize this formulation.

# !!! warning

#     This tutorial is not required for using UnitCommitment.jl, unless you plan to make changes to the problem formulation. In this page, we assume familiarity with the JuMP modeling language. Please see [JuMP's official documentation](https://jump.dev/JuMP.jl/stable/) for resources on getting started with JuMP.

# ## Selecting modeling components

# UnitCommitment.jl uses an extension-based architecture. Each extension handles a specific modeling component (e.g., thermal units, transmission lines, storage). You configure the model by passing extensions to `read` or `read_benchmark` via the `extensions` keyword argument.

# By default, a carefully tested set of extensions is included automatically. When you provide your own extensions, they are merged with the defaults: if your extension occupies the same *slot* as a default one (e.g., `:transmission`), it replaces the default; otherwise, it is appended.

# We start by importing the necessary packages:

using HiGHS
using JuMP
using UnitCommitment

# In the example below, we customize the thermal unit formulation by selecting specific modeling components from the literature, and we override the default transmission extension with custom shift-factor cutoffs:

instance = UnitCommitment.read_benchmark(
    "matpower/case14/2017-01-01",
    extensions = [
        UnitCommitment.ThermalExt(
            pwl_costs = UnitCommitment.KnuOstWat2018.PwlCosts(),
            ramping = UnitCommitment.MorLatRam2013.Ramping(),
            slimits = UnitCommitment.MorLatRam2013.StartupShutdownLimits(),
        ),
        UnitCommitment.ShiftFactorsTransmissionExt(
            isf_cutoff = 0.008,
            lodf_cutoff = 0.003,
        ),
    ],
)
model = UnitCommitment.build_model(instance, optimizer = HiGHS.Optimizer)

# ## Accessing decision variables

# In the previous tutorial, we saw how to access the optimal solution through `UnitCommitment.solution`. While this approach works well for basic usage, it is also possible to get a direct reference to the JuMP decision variables and query their values, as the next example illustrates.

# First, we load a benchmark instance and solve it, as before. Note that `build_model` returns a `UnitCommitmentModel` wrapper. To access the underlying JuMP model directly (e.g., for querying variables or constraints), use `model.inner`.

instance = UnitCommitment.read_benchmark("matpower/case14/2017-01-01");
model = UnitCommitment.build_model(instance, optimizer = HiGHS.Optimizer);
UnitCommitment.optimize!(model)

# At this point, it is possible to obtain a reference to the decision variables by calling `model.inner[:varname][index]`. For example, `model.inner[:is_on]["g1",1]` returns a direct reference to the JuMP variable indicating whether generator named "g1" is on at time 1. For a complete list of decision variables available, and how they are indexed, see the [problem definition](../guides/problem.md).

@show JuMP.value(model.inner[:is_on]["g1", 1])

# To access second-stage decisions, it is necessary to specify the scenario name. UnitCommitment.jl models deterministic instances as a particular case in which there is a single scenario named "s1", so we need to use this key.

@show JuMP.value(model.inner[:prod_above]["s1", "g1", 1])

# ## Modifying variables and constraints

# When testing variations of the unit commitment problem, it is often necessary to modify the objective function, variables and constraints of the formulation. UnitCommitment.jl makes this process relatively easy. The first step is to construct the standard model using `UnitCommitment.build_model`:

instance = UnitCommitment.read_benchmark("matpower/case14/2017-01-01");
model = UnitCommitment.build_model(instance, optimizer = HiGHS.Optimizer);

# Now, before calling `UnitCommitment.optimize!`, we can make any desired changes to the formulation. In the previous section, we saw how to obtain a direct reference to the decision variables. It is possible to modify them by using standard JuMP methods. For example, to fix the commitment status of a particular generator, we can use `JuMP.fix`:

JuMP.fix(model.inner[:is_on]["g1", 1], 1.0, force = true)

# To modify the cost coefficient of a particular variable, we can use `JuMP.set_objective_coefficient`:

JuMP.set_objective_coefficient(model.inner, model.inner[:switch_on]["g1", 1], 1000.0)

# It is also possible to make changes to the set of constraints. For example, we can add a custom constraint, using the `JuMP.@constraint` macro:

@constraint(model.inner, model.inner[:is_on]["g3", 1] + model.inner[:is_on]["g4", 1] <= 1);

# We can also remove an existing model constraint using `JuMP.delete`. See the [problem definition](../guides/problem.md) for a list of constraint names and indices. Constraints must be deleted from both model.inner and from the model.inner[:eq_name] dictionary.

JuMP.delete(model.inner, model.inner[:eq_min_uptime]["g1", 1])
delete!(model.inner[:eq_min_uptime], ("g1", 1))

# After we are done with all changes, we can call `UnitCommitment.optimize!` and extract the optimal solution:

UnitCommitment.optimize!(model)
@show UnitCommitment.solution(model)

# ## Writing a custom extension

# In this section we demonstrate how to write a custom extension that adds a new grid component to the model. Extensions are the recommended way to incorporate new types of generators, loads, storage devices, or any other grid equipment. The extension lifecycle has three core hooks:
#
# 1. **`read_json`** — parse custom data from a JSON instance file.
# 2. **`build_model`** — add variables, constraints, and objective terms to the JuMP model.
# 3. **`store_solution`** — extract results from the solved model into the solution dictionary.
#
# We will build a simple "demand response" extension as a worked example. Each demand-response device can curtail up to a specified amount of load at a given bus, earning a payment for each MW curtailed.

# ### Step 1: Define the extension struct

# Every extension inherits from `UnitCommitmentExtension`. The extension struct itself can be empty or hold configuration parameters.

struct DemandResponseExt <: UnitCommitment.UnitCommitmentExtension end

# We also define a data struct to hold per-device parameters:

Base.@kwdef mutable struct DemandResponseDevice
    name::String
    bus_name::String
    max_curtailment::Vector{Float64}   ## MW, per time step
    payment::Vector{Float64}           ## $/MW, per time step
end

# ### Step 2: Implement `read_json`

# The `read_json` hook is called once per scenario when reading an instance. It receives the raw JSON dictionary, the scenario being populated, and the extension instance. We parse our custom data and store it in `sc[:key]`.

function UnitCommitment.read_json(
    json::AbstractDict,
    sc::UnitCommitment.UnitCommitmentScenario,
    ::DemandResponseExt,
)
    T = sc[:time]
    devices = DemandResponseDevice[]
    if "Demand response" in keys(json)
        for (name, dict) in json["Demand response"]
            push!(
                devices,
                DemandResponseDevice(
                    name = name,
                    bus_name = dict["Bus"],
                    max_curtailment = UnitCommitment.to_timeseries(
                        dict["Max curtailment (MW)"],
                        T,
                    ),
                    payment = UnitCommitment.to_timeseries(
                        dict["Payment (\$/MW)"],
                        T,
                    ),
                ),
            )
        end
    end
    sc[:demand_response] = devices
    return
end

# ### Step 3: Implement `build_model`

# The `build_model` hook receives a raw `JuMP.Model` (not a `UnitCommitmentModel`), the instance, and the extension. Here we create decision variables, contribute to bus net injection via `model[:net_injection]`, and add costs to `model[:obj]`.

function UnitCommitment.build_model(
    model::JuMP.Model,
    instance::UnitCommitment.UnitCommitmentInstance,
    ::DemandResponseExt,
)::Nothing
    T = instance.time

    ## Initialize an OrderedDict to store our variables in the model.
    ## The _init helper creates model[:curtail] as an OrderedDict if it
    ## does not already exist, or returns the existing one.
    curtail = UnitCommitment._init(model, :curtail)

    for sc in instance.scenarios, dr in sc[:demand_response], t in 1:T
        ## Create a bounded variable for each device, scenario, and time step.
        curtail[sc.name, dr.name, t] = @variable(
            model,
            lower_bound = 0,
            upper_bound = dr.max_curtailment[t],
        )

        ## Curtailment reduces net load at the bus, so it acts like
        ## positive injection. We add it to the net_injection expression.
        JuMP.add_to_expression!(
            model[:net_injection][sc.name, dr.bus_name, t],
            curtail[sc.name, dr.name, t],
            1.0,
        )

        ## Subtract the payment from the objective (minimization problem,
        ## so payments are negative costs).
        JuMP.add_to_expression!(
            model[:obj],
            curtail[sc.name, dr.name, t],
            -dr.payment[t],
        )
    end
    return
end

# ### Step 4: Implement `store_solution`

# The `store_solution` hook is called after optimization. Here, `model` is a `UnitCommitmentModel`, so we access the JuMP model via `model.inner` to retrieve variable values.

function UnitCommitment.store_solution(
    sol::AbstractDict,
    model::UnitCommitment.UnitCommitmentModel,
    ::DemandResponseExt,
)::Nothing
    instance = model.instance
    inner = model.inner
    T = instance.time
    for sc in instance.scenarios
        sol[sc.name]["Demand response: Curtailment (MW)"] = OrderedDict(
            dr.name => [
                round(JuMP.value(inner[:curtail][sc.name, dr.name, t]), digits = 5)
                for t in 1:T
            ] for dr in sc[:demand_response]
        )
    end
    return
end

# ### Step 5: Use the extension

# To activate the extension, pass it to `read` or `read_benchmark` via the `extensions` keyword:

## instance = UnitCommitment.read(
##     "my_instance.json",
##     extensions = [DemandResponseExt()],
## )
## model = UnitCommitment.build_model(instance, optimizer = HiGHS.Optimizer)
## UnitCommitment.optimize!(model)
## sol = UnitCommitment.solution(model)

# The extension is merged with the default set of extensions, so thermal units, storage, transmission, and all other built-in components are still included automatically. If your instance JSON file contains a `"Demand response"` section, the extension will parse it and incorporate the devices into the optimization model.
