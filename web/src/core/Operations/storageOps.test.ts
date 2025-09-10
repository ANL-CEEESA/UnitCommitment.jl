/*
 * UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
 * Copyright (C) 2020-2025, UChicago Argonne, LLC. All rights reserved.
 * Released under the modified BSD license. See COPYING.md for more details.
 */

import { TEST_DATA_1 } from "../Data/fixtures.test";
import assert from "node:assert";
import {
  changeStorageUnitData,
  createStorageUnit,
  deleteStorageUnit,
  renameStorageUnit,
} from "./storageOps";
import { ValidationError } from "../Data/validate";

test("createStorageUnit", () => {
  const [newScenario, err] = createStorageUnit(TEST_DATA_1);
  assert(err === null);
  assert.equal(Object.keys(newScenario["Storage units"]).length, 2);
  assert("su2" in newScenario["Storage units"]);
});

test("renameStorageUnit", () => {
  const [newScenario, err] = renameStorageUnit("su1", "su2", TEST_DATA_1);
  assert(err === null);
  assert.deepEqual(
    newScenario["Storage units"]["su2"],
    TEST_DATA_1["Storage units"]["su1"],
  );
  assert.equal(Object.keys(newScenario["Storage units"]).length, 1);
});

test("changeStorageUnitData", () => {
  let scenario = TEST_DATA_1;
  let err: ValidationError | null;
  [scenario, err] = changeStorageUnitData("su1", "Bus", "b3", scenario);
  assert.equal(err, null);
  [scenario, err] = changeStorageUnitData(
    "su1",
    "Minimum level (MWh)",
    "99",
    scenario,
  );
  assert.equal(err, null);
  [scenario, err] = changeStorageUnitData(
    "su1",
    "Maximum discharge rate (MW)",
    "99",
    scenario,
  );
  assert.equal(err, null);
  assert.deepEqual(scenario["Storage units"]["su1"], {
    Bus: "b3",
    "Minimum level (MWh)": 99.0,
    "Maximum level (MWh)": 100.0,
    "Charge cost ($/MW)": 2.0,
    "Discharge cost ($/MW)": 1.0,
    "Charge efficiency": 0.8,
    "Discharge efficiency": 0.85,
    "Loss factor": 0.01,
    "Minimum charge rate (MW)": 5.0,
    "Maximum charge rate (MW)": 10.0,
    "Minimum discharge rate (MW)": 4.0,
    "Maximum discharge rate (MW)": 99.0,
    "Initial level (MWh)": 20.0,
    "Last period minimum level (MWh)": 21.0,
    "Last period maximum level (MWh)": 22.0,
  });
});

test("deleteStorageUnit", () => {
  const newScenario = deleteStorageUnit("su1", TEST_DATA_1);
  assert.equal(Object.keys(newScenario["Storage units"]).length, 0);
});
