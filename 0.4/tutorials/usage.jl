# # Getting started

# ## Installing the package

# UnitCommitment.jl was tested and developed with [Julia 1.10](https://julialang.org/). To install Julia, please follow the [installation guide on the official Julia website](https://julialang.org/downloads/). To install UnitCommitment.jl, run the Julia interpreter, type `]` to open the package manager, then type:

# ```text
# pkg> add UnitCommitment@0.4
# ```

# To solve the optimization models, a mixed-integer linear programming (MILP) solver is also required. Please see the [JuMP installation guide](https://jump.dev/JuMP.jl/stable/installation/) for more instructions on installing a solver. Typical open-source choices are [HiGHS](https://github.com/jump-dev/HiGHS.jl), [Cbc](https://github.com/JuliaOpt/Cbc.jl) and [GLPK](https://github.com/JuliaOpt/GLPK.jl). In the instructions below, HiGHS will be used, but any other MILP solver listed in JuMP installation guide should also be compatible.

# ## Solving a benchmark instance

# We start this tutorial by illustrating how to use UnitCommitment.jl to solve one of the provided benchmark instances. The package contains a large number of deterministic benchmark instances collected from the literature and converted into a common data format, which can be used to evaluate the performance of different solution methods. See [Instances](../guides/instances.md) for more details. The first step is to import `UnitCommitment` and HiGHS.

using HiGHS
using UnitCommitment

# Next, we use the function `read_benchmark` to read the instance.

instance = UnitCommitment.read_benchmark("matpower/case14/2017-01-01");

# Now that we have the instance loaded in memory, we build the JuMP optimization model using `UnitCommitment.build_model`:

model = UnitCommitment.build_model(
    instance=instance,
    optimizer=HiGHS.Optimizer,
);

# Next, we run the optimization process, with `UnitCommitment.optimize!`:

UnitCommitment.optimize!(model)

# Finally, we extract the optimal solution from the model:

solution = UnitCommitment.solution(model)

# We can then explore the solution using Julia:

@show solution["Thermal production (MW)"]["g1"]

# Or export the entire solution to a JSON file:

UnitCommitment.write("solution.json", solution)


# ## Solving a custom deterministic instance

# In the previous example, we solved a benchmark instance provided by the package. To solve a custom instance, the first step is to create an input file describing the list of elements (generators, loads and transmission lines) in the network. See [Data Format](../guides/format.md) for a complete description of the data format UC.jl expects. To keep this tutorial self-contained, we will create the input JSON file using Julia; however, this step can also be done with a simple text editor. First, we define the contents of the file:

json_contents = """
{
    "Parameters": {
        "Version": "0.4",
        "Time horizon (h)": 4
    },
    "Buses": {
        "b1": {
            "Load (MW)": [100, 150, 200, 250]
        }
    },
    "Generators": {
        "g1": {
            "Bus": "b1",
            "Type": "Thermal",
            "Production cost curve (MW)": [0, 200],
            "Production cost curve (\$)": [0, 1000],
            "Initial status (h)": -24,
            "Initial power (MW)": 0
        },
        "g2": {
            "Bus": "b1",
            "Type": "Thermal",
            "Production cost curve (MW)": [0, 300],
            "Production cost curve (\$)": [0, 3000],
            "Initial status (h)": -24,
            "Initial power (MW)": 0
        }
    }
}
""";

# Next, we write it to `example.json`.

open("example.json", "w") do file
    write(file, json_contents)
end;

# Now that we have the input file, we can proceed as before, but using `UnitCommitment.read` instead of `UnitCommitment.read_benchmark`:

instance = UnitCommitment.read("example.json");
model = UnitCommitment.build_model(
    instance=instance,
    optimizer=HiGHS.Optimizer,
);
UnitCommitment.optimize!(model)

# Finally, we extract and display the solution:

solution = UnitCommitment.solution(model)

#

@show solution["Thermal production (MW)"]["g1"]

#

@show solution["Thermal production (MW)"]["g2"]

# ## Solving a custom stochastic instance

# In addition to deterministic test cases, UnitCommitment.jl can also solve two-stage stochastic instances of the problem. In this section, we demonstrate the most simple form, which builds a single (extensive form) model containing information for all scenarios. See [Decomposition](../tutorials/decomposition.md) for more advanced methods.

# First, we need to create one JSON input file for each scenario. Parameters that are allowed to change across scenarios are marked as "uncertain" in the [JSON data format](../guides/format.md) page. It is also possible to specify the name and weight of each scenario, as shown below.

# We start by creating `example_s1.json`, the first scenario file:

json_contents_s1 = """
{
    "Parameters": {
        "Version": "0.4",
        "Time horizon (h)": 4,
        "Scenario name": "s1",
        "Scenario weight": 3.0
    },
    "Buses": {
        "b1": {
            "Load (MW)": [100, 150, 200, 250]
        }
    },
    "Generators": {
        "g1": {
            "Bus": "b1",
            "Type": "Thermal",
            "Production cost curve (MW)": [0, 200],
            "Production cost curve (\$)": [0, 1000],
            "Initial status (h)": -24,
            "Initial power (MW)": 0
        },
        "g2": {
            "Bus": "b1",
            "Type": "Thermal",
            "Production cost curve (MW)": [0, 300],
            "Production cost curve (\$)": [0, 3000],
            "Initial status (h)": -24,
            "Initial power (MW)": 0
        }
    }
}
"""
open("example_s1.json", "w") do file
    write(file, json_contents_s1)
end;

# Next, we create `example_s2.json`, the second scenario file:

json_contents_s2 = """
{
    "Parameters": {
        "Version": "0.4",
        "Time horizon (h)": 4,
        "Scenario name": "s2",
        "Scenario weight": 1.0
    },
    "Buses": {
        "b1": {
            "Load (MW)": [200, 300, 400, 500]
        }
    },
    "Generators": {
        "g1": {
            "Bus": "b1",
            "Type": "Thermal",
            "Production cost curve (MW)": [0, 200],
            "Production cost curve (\$)": [0, 1000],
            "Initial status (h)": -24,
            "Initial power (MW)": 0
        },
        "g2": {
            "Bus": "b1",
            "Type": "Thermal",
            "Production cost curve (MW)": [0, 300],
            "Production cost curve (\$)": [0, 3000],
            "Initial status (h)": -24,
            "Initial power (MW)": 0
        }
    }
}
""";
open("example_s2.json", "w") do file
    write(file, json_contents_s2)
end;

# Now that we have our two scenario files, we can read them using `UnitCommitment.read`. Note that, instead of a single file, we now provide a list.

instance = UnitCommitment.read(["example_s1.json", "example_s2.json"])

# If we have a large number of scenario files, the [Glob](https://github.com/vtjnash/Glob.jl) package can also be used to avoid having to list them individually:

using Glob
instance = UnitCommitment.read(glob("example_s*.json"))

# Finally, we build the model and optimize as before:

model = UnitCommitment.build_model(
    instance=instance,
    optimizer=HiGHS.Optimizer,
);
UnitCommitment.optimize!(model)

# The solution to stochastic instances follows a slightly different format, as shown below:

solution = UnitCommitment.solution(model)

# The solution for each stage can be accessed through `solution[scenario_name]`. For conveniance, this includes both first- and second-stage optimal decisions:

solution["s1"]