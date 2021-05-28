# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

import pandas as pd
import numpy as np
import seaborn as sns
import matplotlib.pyplot as plt
import sys

# easy_cutoff = 120

b1 = pd.read_csv(sys.argv[1], index_col=0)
b2 = pd.read_csv(sys.argv[2], index_col=0)

c1 = b1.groupby(["Group", "Instance", "Sample"])[
    ["Optimization time (s)", "Primal bound"]
].mean()
c2 = b2.groupby(["Group", "Instance", "Sample"])[
    ["Optimization time (s)", "Primal bound"]
].mean()
c1.columns = ["A Time (s)", "A Value"]
c2.columns = ["B Time (s)", "B Value"]

merged = pd.concat([c1, c2], axis=1)
merged["Speedup"] = merged["A Time (s)"] / merged["B Time (s)"]
merged["Time diff (s)"] = merged["B Time (s)"] - merged["A Time (s)"]
merged["Value diff (%)"] = np.round(
    (merged["B Value"] - merged["A Value"]) / merged["A Value"] * 100.0, 5
)
merged.loc[merged.loc[:, "B Time (s)"] <= 0, "Speedup"] = float("nan")
merged.loc[merged.loc[:, "B Time (s)"] <= 0, "Time diff (s)"] = float("nan")
# merged = merged[(merged["A Time (s)"] >= easy_cutoff) | (merged["B Time (s)"] >= easy_cutoff)]
merged.reset_index(inplace=True)
merged["Name"] = merged["Group"] + "/" + merged["Instance"]
# merged = merged.sort_values(by="Speedup", ascending=False)


k = len(merged.groupby("Name"))
plt.figure(figsize=(12, 0.50 * k))
plt.rcParams["xtick.bottom"] = plt.rcParams["xtick.labelbottom"] = True
plt.rcParams["xtick.top"] = plt.rcParams["xtick.labeltop"] = True
sns.set_style("whitegrid")
sns.set_palette("Set1")
sns.barplot(
    data=merged,
    x="Speedup",
    y="Name",
    color="tab:red",
    capsize=0.15,
    errcolor="k",
    errwidth=1.25,
)
plt.axvline(1.0, linestyle="--", color="k")
plt.tight_layout()

print("Writing tables/compare.png")
plt.savefig("tables/compare.png", dpi=150)

print("Writing tables/compare.csv")
merged.loc[
    :,
    [
        "Group",
        "Instance",
        "Sample",
        "A Time (s)",
        "B Time (s)",
        "Speedup",
        "Time diff (s)",
        "A Value",
        "B Value",
        "Value diff (%)",
    ],
].to_csv("tables/compare.csv", index_label="Index")
