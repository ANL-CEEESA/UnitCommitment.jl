# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

from pathlib import Path
import pandas as pd
import re
from tabulate import tabulate


def process_all_log_files():
    pathlist = list(Path(".").glob("results/**/*.log"))
    rows = []
    for path in pathlist:
        if ".ipy" in str(path):
            continue
        row = process(str(path))
        rows += [row]
    df = pd.DataFrame(rows)
    df = df.sort_values(["Group", "Buses"])
    df.index = range(len(df))
    print("Writing tables/benchmark.csv")
    df.to_csv("tables/benchmark.csv", index_label="Index")


def process(filename):
    parts = filename.replace(".log", "").split("/")
    group_name = parts[1]
    instance_name = "/".join(parts[2:-1])
    sample_name = parts[-1]
    nodes = 0.0
    optimize_time = 0.0
    simplex_iterations = 0.0
    primal_bound = None
    dual_bound = None
    gap = None
    root_obj = None
    root_iterations = 0.0
    root_time = 0.0
    n_rows_orig, n_rows_presolved = None, None
    n_cols_orig, n_cols_presolved = None, None
    n_nz_orig, n_nz_presolved = None, None
    n_cont_vars_presolved, n_bin_vars_presolved = None, None
    read_time, model_time, isf_time, total_time = None, None, None, None
    cb_calls, cb_time = 0, 0.0
    transmission_count, transmission_time, transmission_calls = 0, 0.0, 0

    # m = re.search("case([0-9]*)", instance_name)
    # n_buses = int(m.group(1))
    n_buses = 0

    with open(filename) as file:
        for line in file.readlines():
            m = re.search(
                r"Explored ([0-9.e+]*) nodes \(([0-9.e+]*) simplex iterations\) in ([0-9.e+]*) seconds",
                line,
            )
            if m is not None:
                nodes += int(m.group(1))
                simplex_iterations += int(m.group(2))
                optimize_time += float(m.group(3))

            m = re.search(
                r"Best objective ([0-9.e+]*), best bound ([0-9.e+]*), gap ([0-9.e+]*)\%",
                line,
            )
            if m is not None:
                primal_bound = float(m.group(1))
                dual_bound = float(m.group(2))
                gap = round(float(m.group(3)), 3)

            m = re.search(
                r"Root relaxation: objective ([0-9.e+]*), ([0-9.e+]*) iterations, ([0-9.e+]*) seconds",
                line,
            )
            if m is not None:
                root_obj = float(m.group(1))
                root_iterations += int(m.group(2))
                root_time += float(m.group(3))

            m = re.search(
                r"Presolved: ([0-9.e+]*) rows, ([0-9.e+]*) columns, ([0-9.e+]*) nonzeros",
                line,
            )
            if m is not None:
                n_rows_presolved = int(m.group(1))
                n_cols_presolved = int(m.group(2))
                n_nz_presolved = int(m.group(3))

            m = re.search(
                r"Optimize a model with ([0-9.e+]*) rows, ([0-9.e+]*) columns and ([0-9.e+]*) nonzeros",
                line,
            )
            if m is not None:
                n_rows_orig = int(m.group(1))
                n_cols_orig = int(m.group(2))
                n_nz_orig = int(m.group(3))

            m = re.search(
                r"Variable types: ([0-9.e+]*) continuous, ([0-9.e+]*) integer \(([0-9.e+]*) binary\)",
                line,
            )
            if m is not None:
                n_cont_vars_presolved = int(m.group(1))
                n_bin_vars_presolved = int(m.group(3))

            m = re.search(r"Read problem in ([0-9.e+]*) seconds", line)
            if m is not None:
                read_time = float(m.group(1))

            m = re.search(r"Computed ISF in ([0-9.e+]*) seconds", line)
            if m is not None:
                isf_time = float(m.group(1))

            m = re.search(r"Built model in ([0-9.e+]*) seconds", line)
            if m is not None:
                model_time = float(m.group(1))

            m = re.search(r"Total time was ([0-9.e+]*) seconds", line)
            if m is not None:
                total_time = float(m.group(1))

            m = re.search(
                r"User-callback calls ([0-9.e+]*), time in user-callback ([0-9.e+]*) sec",
                line,
            )
            if m is not None:
                cb_calls = int(m.group(1))
                cb_time = float(m.group(2))

            m = re.search(r"Verified transmission limits in ([0-9.e+]*) sec", line)
            if m is not None:
                transmission_time += float(m.group(1))
                transmission_calls += 1

            m = re.search(r".*MW overflow", line)
            if m is not None:
                transmission_count += 1

    return {
        "Group": group_name,
        "Instance": instance_name,
        "Sample": sample_name,
        "Optimization time (s)": optimize_time,
        "Read instance time (s)": read_time,
        "Model construction time (s)": model_time,
        "ISF & LODF computation time (s)": isf_time,
        "Total time (s)": total_time,
        "User-callback time": cb_time,
        "User-callback calls": cb_calls,
        "Gap (%)": gap,
        "B&B Nodes": nodes,
        "Simplex iterations": simplex_iterations,
        "Primal bound": primal_bound,
        "Dual bound": dual_bound,
        "Root relaxation iterations": root_iterations,
        "Root relaxation time": root_time,
        "Root relaxation value": root_obj,
        "Rows": n_rows_orig,
        "Cols": n_cols_orig,
        "Nonzeros": n_nz_orig,
        "Rows (presolved)": n_rows_presolved,
        "Cols (presolved)": n_cols_presolved,
        "Nonzeros (presolved)": n_nz_presolved,
        "Bin vars (presolved)": n_bin_vars_presolved,
        "Cont vars (presolved)": n_cont_vars_presolved,
        "Buses": n_buses,
        "Transmission screening constraints": transmission_count,
        "Transmission screening time": transmission_time,
        "Transmission screening calls": transmission_calls,
    }


def generate_chart():
    import pandas as pd
    import matplotlib
    import matplotlib.pyplot as plt
    import seaborn as sns

    matplotlib.use("Agg")
    sns.set("talk")
    sns.set_palette(
        [
            "#9b59b6",
            "#3498db",
            "#95a5a6",
            "#e74c3c",
            "#34495e",
            "#2ecc71",
        ]
    )

    tables = []
    files = ["tables/benchmark.csv"]
    for f in files:
        table = pd.read_csv(f, index_col=0)
        table.loc[:, "Filename"] = f
        tables += [table]
    benchmark = pd.concat(tables, sort=True)
    benchmark = benchmark.sort_values(by=["Group", "Instance"])
    k1 = len(benchmark.groupby("Instance"))
    k2 = len(benchmark.groupby("Group"))
    plt.figure(figsize=(12, 0.25 * k1 * k2))
    sns.barplot(
        y="Instance",
        x="Total time (s)",
        hue="Group",
        errcolor="k",
        errwidth=1.25,
        data=benchmark,
    )
    plt.tight_layout()
    print("Writing tables/benchmark.png")
    plt.savefig("tables/benchmark.png", dpi=150)


if __name__ == "__main__":
    process_all_log_files()
    generate_chart()
