/*
 * UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
 * Copyright (C) 2020-2025, UChicago Argonne, LLC. All rights reserved.
 * Released under the modified BSD license. See COPYING.md for more details.
 */

import { UnitCommitmentScenario } from "./types";

export const TEST_DATA_1: UnitCommitmentScenario = {
  Parameters: {
    Version: "0.4",
    "Power balance penalty ($/MW)": 1000.0,
    "Time horizon (h)": 5,
    "Time step (min)": 60,
  },
  Buses: {
    b1: { "Load (MW)": [35.79534, 34.38835, 33.45083, 32.89729, 33.25044] },
    b2: { "Load (MW)": [14.03739, 13.48563, 13.11797, 12.9009, 13.03939] },
    b3: { "Load (MW)": [27.3729, 26.29698, 25.58005, 25.15675, 25.4268] },
  },
  Generators: {
    g1: {
      Bus: "b1",
      Type: "Thermal",
      "Production cost curve (MW)": [100.0, 110.0, 130.0, 135.0],
      "Production cost curve ($)": [1400.0, 1600.0, 2200.0, 2400.0],
      "Startup costs ($)": [300.0, 400.0],
      "Startup delays (h)": [1, 4],
      "Ramp up limit (MW)": 232.68,
      "Ramp down limit (MW)": 232.68,
      "Startup limit (MW)": 232.68,
      "Shutdown limit (MW)": 232.68,
      "Minimum downtime (h)": 4,
      "Minimum uptime (h)": 4,
      "Initial status (h)": 12,
      "Initial power (MW)": 115,
      "Must run?": false,
    },
    pu1: {
      Bus: "b1",
      Type: "Profiled",
      "Cost ($/MW)": 12.5,
      "Maximum power (MW)": [10, 12, 13, 15, 20],
      "Minimum power (MW)": [0, 0, 0, 0, 0],
    },
    pu2: {
      Bus: "b1",
      Type: "Profiled",
      "Cost ($/MW)": 120,
      "Maximum power (MW)": [50, 50, 50, 50, 50],
      "Minimum power (MW)": [0, 0, 0, 0, 0],
    },
  },
  "Transmission lines": {
    l1: {
      "Source bus": "b1",
      "Target bus": "b2",
      "Susceptance (S)": 29.49686,
      "Normal flow limit (MW)": 15000.0,
      "Emergency flow limit (MW)": 20000.0,
      "Flow limit penalty ($/MW)": 5000.0,
    },
  },
};

export const TEST_DATA_2: UnitCommitmentScenario = {
  Parameters: {
    Version: "0.4",
    "Power balance penalty ($/MW)": 1000.0,
    "Time horizon (h)": 2,
    "Time step (min)": 30,
  },
  Buses: {
    b1: { "Load (MW)": [30, 30, 30, 30] },
    b2: { "Load (MW)": [10, 20, 30, 40] },
    b3: { "Load (MW)": [0, 30, 0, 40] },
  },
  Generators: {},
  "Transmission lines": {},
};

export const TEST_DATA_BLANK: UnitCommitmentScenario = {
  Parameters: {
    Version: "0.4",
    "Power balance penalty ($/MW)": 1000.0,
    "Time horizon (h)": 5,
    "Time step (min)": 60,
  },
  Buses: {},
  Generators: {},
  "Transmission lines": {},
};

test("fixtures", () => {});
