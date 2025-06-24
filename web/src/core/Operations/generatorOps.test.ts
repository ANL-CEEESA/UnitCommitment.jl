/*
 * UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
 * Copyright (C) 2020-2025, UChicago Argonne, LLC. All rights reserved.
 * Released under the modified BSD license. See COPYING.md for more details.
 */

import { TEST_DATA_1, TEST_DATA_BLANK } from "../fixtures.test";
import assert from "node:assert";
import {
  createProfiledUnit,
  deleteGenerator,
  renameGenerator,
} from "./generatorOps";

test("createProfiledUnit", () => {
  const [newScenario, err] = createProfiledUnit(TEST_DATA_1);
  assert(err === null);
  assert.deepEqual(newScenario.Generators, {
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
    pu3: {
      Bus: "b1",
      Type: "Profiled",
      "Cost ($/MW)": 0,
      "Maximum power (MW)": [0, 0, 0, 0, 0],
      "Minimum power (MW)": [0, 0, 0, 0, 0],
    },
  });
});

test("createProfiledUnit with blank file", () => {
  const [_, err] = createProfiledUnit(TEST_DATA_BLANK);
  assert(err !== null);
  assert.equal(err.message, "Profiled unit requires an existing bus.");
});

test("deleteGenerator", () => {
  const newScenario = deleteGenerator("pu1", TEST_DATA_1);
  assert.deepEqual(newScenario.Generators, {
    pu2: {
      Bus: "b1",
      Type: "Profiled",
      "Cost ($/MW)": 120,
      "Maximum power (MW)": [50, 50, 50, 50, 50],
      "Minimum power (MW)": [0, 0, 0, 0, 0],
    },
  });
});

test("renameGenerator", () => {
  const [newScenario, err] = renameGenerator("pu1", "pu5", TEST_DATA_1);
  assert(err === null);
  assert.deepEqual(newScenario.Generators, {
    pu5: {
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
  });
});
