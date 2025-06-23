/*
 * UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
 * Copyright (C) 2020-2025, UChicago Argonne, LLC. All rights reserved.
 * Released under the modified BSD license. See COPYING.md for more details.
 */

import { TEST_DATA_1, TEST_DATA_BLANK } from "../fixtures.test";
import assert from "node:assert";
import { createProfiledUnit } from "./profiledUnitOps";

test("createUnit", () => {
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
      "Cost ($/MW)": 0,
      "Maximum power (MW)": [0, 0, 0, 0, 0],
      "Minimum power (MW)": [0, 0, 0, 0, 0],
    },
  });
});

test("createUnit with blank file", () => {
  const [newScenario, err] = createProfiledUnit(TEST_DATA_BLANK);
  assert(err !== null);
  assert.equal(err.message, "Profiled unit requires an existing bus.");
});
