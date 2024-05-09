
# ## Generating initial conditions

# When creating random unit commitment instances for benchmark purposes, it is often hard to compute, in advance, sensible initial conditions for all thermal generators. Setting initial conditions naively (for example, making all generators initially off and producing no power) can easily cause the instance to become infeasible due to excessive ramping. Initial conditions can also make it hard to modify existing instances. For example, increasing the system load without carefully modifying the initial conditions may make the problem infeasible or unrealistically challenging to solve.

# To help with this issue, UC.jl provides a utility function which can generate feasible initial conditions by solving a single-period optimization problem. To illustrate its usage, we first generate a JSON file without initial conditions:

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
            "Production cost curve (\$)": [0, 1000]
        },
        "g2": {
            "Bus": "b1",
            "Type": "Thermal",
            "Production cost curve (MW)": [0, 300],
            "Production cost curve (\$)": [0, 3000]
        }
    }
}
""";
open("example_initial.json", "w") do file
    write(file, json_contents)
end;

# Next, we read the instance and generate the initial conditions (in-place):

instance = UnitCommitment.read("example_initial.json")
UnitCommitment.generate_initial_conditions!(instance, HiGHS.Optimizer)

# Finally, we optimize the resulting problem:

model = UnitCommitment.build_model(
    instance=instance,
    optimizer=HiGHS.Optimizer,
)
UnitCommitment.optimize!(model)

# !!! warning

#     The function `generate_initial_conditions!` may return different initial conditions after each call, even if the same instance and the same optimizer is provided. The particular algorithm may also change in a future version of UC.jl. For these reasons, it is recommended that you generate initial conditions exactly once for each instance and store them for later use.

# ## 6. Verifying solutions

# When developing new formulations, it is very easy to introduce subtle errors in the model that result in incorrect solutions. To help avoiding this, UC.jl includes a utility function that verifies if a given solution is feasible, and, if not, prints all the validation errors it found. The implementation of this function is completely independent from the implementation of the optimization model, and therefore can be used to validate it.

# ```jldoctest; output = false
# using JSON
# using UnitCommitment

# # Read instance
# instance = UnitCommitment.read("example/s1.json")

# # Read solution (potentially produced by other packages)
# solution = JSON.parsefile("example/out.json")

# # Validate solution and print validation errors
# UnitCommitment.validate(instance, solution)

# # output

# true
# ```
