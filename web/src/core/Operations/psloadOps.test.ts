/*
 * UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
 * Copyright (C) 2020-2025, UChicago Argonne, LLC. All rights reserved.
 * Released under the modified BSD license. See COPYING.md for more details.
 */

import { TEST_DATA_1 } from "../Data/fixtures.test";
import assert from "node:assert";
import {
  changePriceSensitiveLoadData,
  createPriceSensitiveLoad,
  deletePriceSensitiveLoad,
  renamePriceSensitiveLoad,
} from "./psloadOps";
import { ValidationError } from "../Data/validate";

test("createPriceSensitiveLoad", () => {
  const [newScenario, err] = createPriceSensitiveLoad(TEST_DATA_1);
  assert(err === null);
  assert.equal(Object.keys(newScenario["Price-sensitive loads"]).length, 2);
  assert("ps2" in newScenario["Price-sensitive loads"]);
});

test("renamePriceSensitiveLoad", () => {
  const [newScenario, err] = renamePriceSensitiveLoad(
    "ps1",
    "ps2",
    TEST_DATA_1,
  );
  assert(err === null);
  assert.deepEqual(
    newScenario["Price-sensitive loads"]["ps2"],
    TEST_DATA_1["Price-sensitive loads"]["ps1"],
  );
  assert.equal(Object.keys(newScenario["Price-sensitive loads"]).length, 1);
});

test("changePriceSensitiveLoadData", () => {
  let scenario = TEST_DATA_1;
  let err: ValidationError | null;
  [scenario, err] = changePriceSensitiveLoadData("ps1", "Bus", "b3", scenario);
  assert.equal(err, null);
  [scenario, err] = changePriceSensitiveLoadData(
    "ps1",
    "Demand (MW) 00:00",
    "99",
    scenario,
  );
  assert.equal(err, null);
  assert.deepEqual(scenario["Price-sensitive loads"]["ps1"], {
    Bus: "b3",
    "Revenue ($/MW)": 23,
    "Demand (MW)": [99, 50, 50, 50, 50],
  });
});

test("deletePriceSensitiveLoad", () => {
  const newScenario = deletePriceSensitiveLoad("ps1", TEST_DATA_1);
  assert.equal(Object.keys(newScenario["Price-sensitive loads"]).length, 0);
});
