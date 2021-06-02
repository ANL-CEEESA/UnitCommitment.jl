# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

import pandas as pd
import numpy as np
import seaborn as sns
import matplotlib
import matplotlib.pyplot as plt
import sys

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

filename = sys.argv[1]
m1 = sys.argv[2]
m2 = sys.argv[3]

# Prepare data
data = pd.read_csv(filename, index_col=0)
b1 = (
    data[data["Group"] == m1]
    .groupby(["Instance", "Sample"])
    .mean()[["Optimization time (s)"]]
)
b2 = (
    data[data["Group"] == m2]
    .groupby(["Instance", "Sample"])
    .mean()[["Optimization time (s)"]]
)
b1.columns = [f"{m1} time (s)"]
b2.columns = [f"{m2} time (s)"]
merged = pd.merge(b1, b2, left_index=True, right_index=True).reset_index().dropna()
merged["Speedup"] = merged[f"{m1} time (s)"] / merged[f"{m2} time (s)"]
merged["Group"] = merged["Instance"].str.replace(r"\/.*", "", regex=True)
merged = merged.sort_values(by=["Instance", "Sample"], ascending=True)
merged = merged[(merged[f"{m1} time (s)"] > 0) & (merged[f"{m2} time (s)"] > 0)]

# Plot results
k1 = len(merged.groupby("Instance").mean())
k2 = len(merged.groupby("Group").mean())
k = k1 + k2
fig = plt.figure(
    constrained_layout=True,
    figsize=(15, max(5, 0.75 * k)),
)
plt.suptitle(f"{m1} vs {m2}")
gs1 = fig.add_gridspec(nrows=k, ncols=1)
ax1 = fig.add_subplot(gs1[0:k1, 0:1])
ax2 = fig.add_subplot(gs1[k1:, 0:1], sharex=ax1)
sns.barplot(
    data=merged,
    x="Speedup",
    y="Instance",
    color="tab:purple",
    errcolor="k",
    errwidth=1.25,
    ax=ax1,
)
sns.barplot(
    data=merged,
    x="Speedup",
    y="Group",
    color="tab:purple",
    errcolor="k",
    errwidth=1.25,
    ax=ax2,
)
ax1.axvline(1.0, linestyle="--", color="k")
ax2.axvline(1.0, linestyle="--", color="k")

print("Writing tables/compare.png")
plt.savefig("tables/compare.png", dpi=150)

print("Writing tables/compare.csv")
merged.to_csv("tables/compare.csv", index_label="Index")
