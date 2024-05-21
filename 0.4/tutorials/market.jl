# # Market Clearing

# In North America, electricity markets are structured around two primary types of markets: the day-ahead (DA) market and the real-time (RT) market. The DA market schedules electricity generation and consumption for the next day, based on forecasts and bids from electricity suppliers and consumers. The RT market, on the other hand, operates continuously throughout the day, addressing the discrepancies between the DA schedule and actual demand, typically every five minutes. UnitCommitment.jl is able to simulate the DA and RT market clearing process. Specifically, the package provides the function `UnitCommitment.solve_market` which performs the following steps:

# 1. Solve the DA market problem.
# 2. Extract commitment status of all generators.
# 3. Solve a sequence of RT market problems, fixing the commitment status of each generator to the corresponding optimal solution of the DA problem.

# To use this function, we need to prepare an instance file corresponding to the DA market problem and multiple instance files corresponding to the RT market problems. The number of required files depends on the time granularity and window. For example, suppose that the DA problem is solved at hourly granularity and has 24 time periods, whereas the RT problems are solved at 5-minute granularity and have a single time period. Then we would need to prepare one files for the DA problem and 288 files $\left(24 \times \frac{60}{5}\right)$ for the RT market problems.

# ## A small example

# For simplicity, in this tutorial we illustate the usage of `UnitCommitment.solve_market` with a very small example, in which the DA problem has only two time periods. We start by creating the DA instance file:

da_contents = """
{
    "Parameters": {
        "Version": "0.4",
        "Time horizon (h)": 2
    },
    "Buses": {
        "b1": {
            "Load (MW)": [200, 400]
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

open("da.json", "w") do file
    return write(file, da_contents)
end;

# Next, we create eight single-period RT market problems, each one with a 15-minute time granularity:

for i in 1:8
    rt_contents = """
    {
        "Parameters": {
            "Version": "0.4",
            "Time horizon (min)": 15,
            "Time step (min)": 15
        },
        "Buses": {
            "b1": {
                "Load (MW)": [$(150 + 50 * i)]
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
    open("rt_$i.json", "w") do file
        return write(file, rt_contents)
    end
end

# Finally, we call `UnitCommitment.solve_market`, providing as arguments (1) the path to the DA problem; (2) a list of paths to the RT problems; (3) the mixed-integer linear optimizer.

using UnitCommitment
using HiGHS

solution = UnitCommitment.solve_market(
    "da.json",
    [
        "rt_1.json",
        "rt_2.json",
        "rt_3.json",
        "rt_4.json",
        "rt_5.json",
        "rt_6.json",
        "rt_7.json",
        "rt_8.json",
    ],
    optimizer = HiGHS.Optimizer,
)

# To retrieve the day-ahead market solution, we can query `solution["DA"]`:

@show solution["DA"]

# To query each real-time market solution, we can query `solution["RT"][i]`. Note that LMPs are automativally calculated.

@show solution["RT"][1]

# ## Customizing the model and LMPs

# When using the `solve_market` function it is still possible to customize the problem formulation and the LMP calculation method. In the next example, we use a custom formulation and explicitly specify the LMP method through the `settings` keyword argument:

UnitCommitment.solve_market(
    "da.json",
    [
        "rt_1.json",
        "rt_2.json",
        "rt_3.json",
        "rt_4.json",
        "rt_5.json",
        "rt_6.json",
        "rt_7.json",
        "rt_8.json",
    ],
    settings = UnitCommitment.MarketSettings(
        lmp_method = UnitCommitment.ConventionalLMP(),
        formulation = UnitCommitment.Formulation(
            pwl_costs = UnitCommitment.KnuOstWat2018.PwlCosts(),
            ramping = UnitCommitment.MorLatRam2013.Ramping(),
            startup_costs = UnitCommitment.MorLatRam2013.StartupCosts(),
            transmission = UnitCommitment.ShiftFactorsFormulation(
                isf_cutoff = 0.008,
                lodf_cutoff = 0.003,
            ),
        ),
    ),
    optimizer = HiGHS.Optimizer,
)

# It is also possible to add custom variables and constraints to either the DA or RT market problems, through the usage of `after_build_da` and `after_build_rt` callback functions. Similarly, the `after_optimize_da` and `after_optimize_rt` can be used to directly analyze the JuMP models, after they have been optimized:

using JuMP

function after_build_da(model, instance)
    @constraint(model, model[:is_on]["g1", 1] <= model[:is_on]["g2", 1])
end

function after_optimize_da(solution, model, instance)
    @show value(model[:is_on]["g1", 1])
end

UnitCommitment.solve_market(
    "da.json",
    [
        "rt_1.json",
        "rt_2.json",
        "rt_3.json",
        "rt_4.json",
        "rt_5.json",
        "rt_6.json",
        "rt_7.json",
        "rt_8.json",
    ],
    after_build_da = after_build_da,
    after_optimize_da = after_optimize_da,
    optimizer = HiGHS.Optimizer,
)

# ## Additional considerations

# - UC.jl supports two-stage stochastic DA market problems. In this case, we need one file for each DA market scenario. All RT market problems must be deterministic.
# - UC.jl also supports multi-period RT market problems. Assume, for example, that the DA market problem is an hourly problem with 24 time periods, whereas the RT market problem uses 5-minute granularity with 4 time periods. UC.jl assumes that the first RT file covers period `0:00` to `0:20`, the second covers `0:05` to `0:25` and so on. We therefore still need 288 RT market files. To avoid going beyond the 24-hour period covered by the DA market solution, however, the last few RT market problems must have only 3, 2, and 1 time periods, covering `23:45` to `24:00`, `23:50` to `24:00` and `23:55` to `24:00`, respectively.
# - Some MILP solvers (such as Cbc) have issues handling linear programming problems, which are required for the RT market. In this case, a separate linear programming solver can be provided to `solve_market` using the `lp_optimizer` argument. For example, `solve_market(da_file, rt_files, optimizer=Cbc.Optimizer, lp_optimizer=Clp.Optimizer)`.
