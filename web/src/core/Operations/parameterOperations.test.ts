/*
 * UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
 * Copyright (C) 2020-2025, UChicago Argonne, LLC. All rights reserved.
 * Released under the modified BSD license. See COPYING.md for more details.
 */

import {
  changeTimeHorizon,
  changeTimeStep,
  evaluatePwlFunction,
} from "./parameterOperations";
import assert from "node:assert";
import { TEST_DATA_1, TEST_DATA_2 } from "../fixtures.test";

test("changeTimeHorizon: Shrink 1", () => {
  const [newScenario, err] = changeTimeHorizon(TEST_DATA_1, "3");
  assert(err === null);
  assert.deepEqual(newScenario, {
    Parameters: {
      Version: "0.4",
      "Power balance penalty ($/MW)": 1000.0,
      "Time horizon (h)": 3,
      "Time step (min)": 60,
    },
    Buses: {
      b1: { "Load (MW)": [35.79534, 34.38835, 33.45083] },
      b2: { "Load (MW)": [14.03739, 13.48563, 13.11797] },
      b3: { "Load (MW)": [27.3729, 26.29698, 25.58005] },
    },
  });
});

test("changeTimeHorizon: Shrink 2", () => {
  const [newScenario, err] = changeTimeHorizon(TEST_DATA_2, "1");
  assert(err === null);
  assert.deepEqual(newScenario, {
    Parameters: {
      Version: "0.4",
      "Power balance penalty ($/MW)": 1000.0,
      "Time horizon (h)": 1,
      "Time step (min)": 30,
    },
    Buses: {
      b1: { "Load (MW)": [30, 30] },
      b2: { "Load (MW)": [10, 20] },
      b3: { "Load (MW)": [0, 30] },
    },
  });
});

test("changeTimeHorizon grow", () => {
  const [newScenario, err] = changeTimeHorizon(TEST_DATA_1, "7");
  assert(err === null);
  assert.deepEqual(newScenario, {
    Parameters: {
      Version: "0.4",
      "Power balance penalty ($/MW)": 1000.0,
      "Time horizon (h)": 7,
      "Time step (min)": 60,
    },
    Buses: {
      b1: {
        "Load (MW)": [35.79534, 34.38835, 33.45083, 32.89729, 33.25044, 0, 0],
      },
      b2: {
        "Load (MW)": [14.03739, 13.48563, 13.11797, 12.9009, 13.03939, 0, 0],
      },
      b3: {
        "Load (MW)": [27.3729, 26.29698, 25.58005, 25.15675, 25.4268, 0, 0],
      },
    },
  });
});

test("changeTimeHorizon invalid", () => {
  let [, err] = changeTimeHorizon(TEST_DATA_1, "x");
  assert(err !== null);
  assert.equal(err.message, "Invalid value: x");

  [, err] = changeTimeHorizon(TEST_DATA_1, "-3");
  assert(err !== null);
  assert.equal(err.message, "Invalid value: -3");
});

test("evaluatePwlFunction", () => {
  const data_x = [0, 60, 120, 180];
  const data_y = [100, 200, 250, 100];
  assert.equal(evaluatePwlFunction(data_x, data_y, 0), 100);
  assert.equal(evaluatePwlFunction(data_x, data_y, 15), 125);
  assert.equal(evaluatePwlFunction(data_x, data_y, 30), 150);
  assert.equal(evaluatePwlFunction(data_x, data_y, 60), 200);
  assert.equal(evaluatePwlFunction(data_x, data_y, 180), 100);
});

test("changeTimeStep", () => {
  let [scenario, err] = changeTimeStep(TEST_DATA_2, "15");
  assert(err === null);
  assert.deepEqual(scenario, {
    Parameters: {
      Version: "0.4",
      "Power balance penalty ($/MW)": 1000.0,
      "Time horizon (h)": 2,
      "Time step (min)": 15,
    },
    Buses: {
      b1: { "Load (MW)": [30, 30, 30, 30, 30, 30, 30, 30] },
      b2: { "Load (MW)": [10, 15, 20, 25, 30, 35, 40, 25] },
      b3: { "Load (MW)": [0, 15, 30, 15, 0, 20, 40, 20] },
    },
  });

  [scenario, err] = changeTimeStep(TEST_DATA_2, "60");
  assert(err === null);
  assert.deepEqual(scenario, {
    Parameters: {
      Version: "0.4",
      "Power balance penalty ($/MW)": 1000.0,
      "Time horizon (h)": 2,
      "Time step (min)": 60,
    },
    Buses: {
      b1: { "Load (MW)": [30, 30] },
      b2: { "Load (MW)": [10, 30] },
      b3: { "Load (MW)": [0, 0] },
    },
  });
});

test("changeTimeStep invalid", () => {
  let [, err] = changeTimeStep(TEST_DATA_2, "x");
  assert(err !== null);
  assert.equal(err.message, "Invalid value: x");

  [, err] = changeTimeStep(TEST_DATA_2, "-10");
  assert(err !== null);
  assert.equal(err.message, "Invalid value: -10");

  [, err] = changeTimeStep(TEST_DATA_2, "120");
  assert(err !== null);
  assert.equal(err.message, "Invalid value: 120");

  [, err] = changeTimeStep(TEST_DATA_2, "7");
  assert(err !== null);
  assert.equal(err.message, "Time step must be a divisor of 60: 7");
});

export {};
