/*
 * UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
 * Copyright (C) 2020-2025, UChicago Argonne, LLC. All rights reserved.
 * Released under the modified BSD license. See COPYING.md for more details.
 */

import assert from "node:assert";
import { preprocess } from "./preprocessing";

export const PREPROCESSING_TEST_DATA_1: any = {
  Parameters: {
    Version: "0.4",
    "Time horizon (h)": 5,
  },
  Buses: {
    b1: { "Load (MW)": [35.79534, 34.38835, 33.45083, 32.89729, 33.25044] },
    b2: { "Load (MW)": 10 },
    b3: { "Load (MW)": [27.3729, 26.29698, 25.58005, 25.15675, 25.4268] },
  },
};

test("preprocess", () => {
  const [newScenario, err] = preprocess(PREPROCESSING_TEST_DATA_1);
  assert(err === null);
  assert.deepEqual(newScenario, {
    Parameters: {
      Version: "0.4",
      "Time horizon (h)": 5,
      "Power balance penalty ($/MW)": 1000,
      "Scenario name": "s1",
      "Scenario weight": 1,
      "Time step (min)": 60,
    },
    Buses: {
      b1: { "Load (MW)": [35.79534, 34.38835, 33.45083, 32.89729, 33.25044] },
      b2: { "Load (MW)": [10, 10, 10, 10, 10] },
      b3: { "Load (MW)": [27.3729, 26.29698, 25.58005, 25.15675, 25.4268] },
    },
    "Price-sensitive loads": {},
    "Storage units": {},
    "Transmission lines": {},
    Contingencies: {},
    Generators: {},
    Reserves: {},
  });
});
