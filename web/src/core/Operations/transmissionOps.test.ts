/*
 * UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
 * Copyright (C) 2020-2025, UChicago Argonne, LLC. All rights reserved.
 * Released under the modified BSD license. See COPYING.md for more details.
 */

import { TEST_DATA_1 } from "../Data/fixtures.test";
import assert from "node:assert";
import {
  changeTransmissionLineData,
  createTransmissionLine,
  deleteTransmissionLine,
  renameTransmissionLine,
} from "./transmissionOps";
import { ValidationError } from "../Data/validate";

test("createTransmissionLine", () => {
  const [newScenario, err] = createTransmissionLine(TEST_DATA_1);
  assert(err === null);
  assert.equal(Object.keys(newScenario["Transmission lines"]).length, 2);
  assert("l2" in newScenario["Transmission lines"]);
});

test("renameTransmissionLine", () => {
  const [newScenario, err] = renameTransmissionLine("l1", "l3", TEST_DATA_1);
  assert(err === null);
  assert.deepEqual(newScenario["Transmission lines"]["l3"], {
    "Source bus": "b1",
    "Target bus": "b2",
    "Susceptance (S)": 29.49686,
    "Normal flow limit (MW)": 15000.0,
    "Emergency flow limit (MW)": 20000.0,
    "Flow limit penalty ($/MW)": 5000.0,
  });
  assert.equal(Object.keys(newScenario["Transmission lines"]).length, 1);
});

test("changeTransmissionLineData", () => {
  let scenario = TEST_DATA_1;
  let err: ValidationError | null;
  [scenario, err] = changeTransmissionLineData(
    "l1",
    "Source bus",
    "b3",
    scenario,
  );
  assert.equal(err, null);
  [scenario, err] = changeTransmissionLineData(
    "l1",
    "Normal flow limit (MW)",
    "99",
    scenario,
  );
  assert.equal(err, null);
  [scenario, err] = changeTransmissionLineData(
    "l1",
    "Target bus",
    "b1",
    scenario,
  );
  assert.equal(err, null);
  assert.deepEqual(scenario["Transmission lines"]["l1"], {
    "Source bus": "b3",
    "Target bus": "b1",
    "Susceptance (S)": 29.49686,
    "Normal flow limit (MW)": 99,
    "Emergency flow limit (MW)": 20000.0,
    "Flow limit penalty ($/MW)": 5000.0,
  });
});

test("deleteTransmissionLine", () => {
  const newScenario = deleteTransmissionLine("l1", TEST_DATA_1);
  assert.equal(Object.keys(newScenario["Transmission lines"]).length, 0);
});
