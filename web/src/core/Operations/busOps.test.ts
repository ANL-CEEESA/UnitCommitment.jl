/*
 * UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
 * Copyright (C) 2020-2025, UChicago Argonne, LLC. All rights reserved.
 * Released under the modified BSD license. See COPYING.md for more details.
 */

import { changeBusData, createBus, deleteBus, renameBus } from "./busOps";
import assert from "node:assert";
import { TEST_DATA_1 } from "../fixtures.test";

test("createBus", () => {
  const newScenario = createBus(TEST_DATA_1);
  assert.deepEqual(Object.keys(newScenario.Buses), ["b1", "b2", "b3", "b4"]);
});

test("changeBusData", () => {
  let scenario = TEST_DATA_1;
  let err = null;

  [scenario, err] = changeBusData("b1", "Load (MW) 00:00", "99", scenario);
  assert.equal(err, null);
  [scenario, err] = changeBusData("b1", "Load (MW) 03:00", "99", scenario);
  assert.equal(err, null);

  [scenario, err] = changeBusData("b3", "Load (MW) 04:00", "99", scenario);
  assert.equal(err, null);

  assert.deepEqual(scenario.Buses, {
    b1: { "Load (MW)": [99, 34.38835, 33.45083, 99, 33.25044] },
    b2: { "Load (MW)": [14.03739, 13.48563, 13.11797, 12.9009, 13.03939] },
    b3: { "Load (MW)": [27.3729, 26.29698, 25.58005, 25.15675, 99] },
  });
});

test("changeBusData with invalid numbers", () => {
  let [, err] = changeBusData("b1", "Load (MW) 00:00", "xx", TEST_DATA_1);
  assert(err !== null);
  assert.equal(err.message, "Invalid value: xx");
});

test("deleteBus", () => {
  let scenario = TEST_DATA_1;
  scenario = deleteBus("b2", scenario);
  assert.deepEqual(scenario.Buses, {
    b1: { "Load (MW)": [35.79534, 34.38835, 33.45083, 32.89729, 33.25044] },
    b3: { "Load (MW)": [27.3729, 26.29698, 25.58005, 25.15675, 25.4268] },
  });
});

test("renameBus", () => {
  let [scenario, err] = renameBus("b2", "b99", TEST_DATA_1);
  assert(err === null);
  assert.deepEqual(scenario.Buses, {
    b1: { "Load (MW)": [35.79534, 34.38835, 33.45083, 32.89729, 33.25044] },
    b99: { "Load (MW)": [14.03739, 13.48563, 13.11797, 12.9009, 13.03939] },
    b3: { "Load (MW)": [27.3729, 26.29698, 25.58005, 25.15675, 25.4268] },
  });
});

test("renameBus with duplicated name", () => {
  let [, err] = renameBus("b3", "b1", TEST_DATA_1);
  assert(err != null);
  assert.equal(err.message, `b1 already exists`);
});
