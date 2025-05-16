/*
 * UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
 * Copyright (C) 2020-2025, UChicago Argonne, LLC. All rights reserved.
 * Released under the modified BSD license. See COPYING.md for more details.
 */

import { UnitCommitmentScenario } from "../fixtures";
import {
  changeBusData,
  createBus,
  deleteBus,
  renameBus,
} from "./busOperations";
import assert from "node:assert";

export const BUS_TEST_DATA_1: UnitCommitmentScenario = {
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
};

export const BUS_TEST_DATA_2: UnitCommitmentScenario = {
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
};

test("createBus", () => {
  const newScenario = createBus(BUS_TEST_DATA_1);
  assert.deepEqual(Object.keys(newScenario.Buses), ["b1", "b2", "b3", "b4"]);
});

test("changeBusData", () => {
  let scenario = BUS_TEST_DATA_1;
  let err = null;

  [scenario, err] = changeBusData("b1", "Load 0", "99", scenario);
  assert.equal(err, null);

  [scenario, err] = changeBusData("b1", "Load 3", "99", scenario);
  assert.equal(err, null);

  [scenario, err] = changeBusData("b3", "Load 4", "99", scenario);
  assert.equal(err, null);

  assert.deepEqual(scenario, {
    Parameters: {
      Version: "0.4",
      "Power balance penalty ($/MW)": 1000.0,
      "Time horizon (h)": 5,
      "Time step (min)": 60,
    },
    Buses: {
      b1: { "Load (MW)": [99, 34.38835, 33.45083, 99, 33.25044] },
      b2: { "Load (MW)": [14.03739, 13.48563, 13.11797, 12.9009, 13.03939] },
      b3: { "Load (MW)": [27.3729, 26.29698, 25.58005, 25.15675, 99] },
    },
  });
});

test("changeBusData with invalid numbers", () => {
  let [, err] = changeBusData("b1", "Load 0", "xx", BUS_TEST_DATA_1);
  assert(err !== null);
  assert.equal(err.message, "Invalid value: xx");
});

test("deleteBus", () => {
  let scenario = BUS_TEST_DATA_1;
  scenario = deleteBus("b2", scenario);
  assert.deepEqual(scenario, {
    Parameters: {
      Version: "0.4",
      "Power balance penalty ($/MW)": 1000.0,
      "Time horizon (h)": 5,
      "Time step (min)": 60,
    },
    Buses: {
      b1: { "Load (MW)": [35.79534, 34.38835, 33.45083, 32.89729, 33.25044] },
      b3: { "Load (MW)": [27.3729, 26.29698, 25.58005, 25.15675, 25.4268] },
    },
  });
});

test("renameBus", () => {
  let [scenario, err] = renameBus("b2", "b99", BUS_TEST_DATA_1);
  assert(err === null);
  assert.deepEqual(scenario, {
    Parameters: {
      Version: "0.4",
      "Power balance penalty ($/MW)": 1000.0,
      "Time horizon (h)": 5,
      "Time step (min)": 60,
    },
    Buses: {
      b1: { "Load (MW)": [35.79534, 34.38835, 33.45083, 32.89729, 33.25044] },
      b99: { "Load (MW)": [14.03739, 13.48563, 13.11797, 12.9009, 13.03939] },
      b3: { "Load (MW)": [27.3729, 26.29698, 25.58005, 25.15675, 25.4268] },
    },
  });
});

test("renameBus with duplicated name", () => {
  let [, err] = renameBus("b3", "b1", BUS_TEST_DATA_1);
  assert(err != null);
  assert.equal(err.message, `Bus b1 already exists`);
});
