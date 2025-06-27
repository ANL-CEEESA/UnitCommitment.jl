/*
 * UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
 * Copyright (C) 2020-2025, UChicago Argonne, LLC. All rights reserved.
 * Released under the modified BSD license. See COPYING.md for more details.
 */

import { TEST_DATA_1, TEST_DATA_BLANK } from "../Data/fixtures.test";
import assert from "node:assert";
import {
  changeProfiledUnitData,
  changeThermalUnitData,
  createProfiledUnit,
  createThermalUnit,
  deleteGenerator,
  renameGenerator,
} from "./generatorOps";
import { ValidationError } from "../Data/validate";

test("createProfiledUnit", () => {
  const [newScenario, err] = createProfiledUnit(TEST_DATA_1);
  assert(err === null);
  assert.equal(Object.keys(newScenario.Generators).length, 4);
  assert("pu3" in newScenario.Generators);
});

test("createThermalUnit", () => {
  const [newScenario, err] = createThermalUnit(TEST_DATA_1);
  assert(err === null);
  assert.equal(Object.keys(newScenario.Generators).length, 4);
  assert("g2" in newScenario.Generators);
});

test("createProfiledUnit with blank file", () => {
  const [, err] = createProfiledUnit(TEST_DATA_BLANK);
  assert(err !== null);
  assert.equal(err.message, "Profiled unit requires an existing bus.");
});

test("changeProfiledUnitData", () => {
  let scenario = TEST_DATA_1;
  let err: ValidationError | null;
  [scenario, err] = changeProfiledUnitData(
    "pu1",
    "Cost ($/MW)",
    "99",
    scenario,
  );
  assert.equal(err, null);
  [scenario, err] = changeProfiledUnitData(
    "pu1",
    "Maximum power (MW) 03:00",
    "99",
    scenario,
  );
  assert.equal(err, null);
  [scenario, err] = changeProfiledUnitData("pu2", "Bus", "b3", scenario);
  assert.equal(err, null);
  assert.deepEqual(scenario.Generators["pu2"], {
    Bus: "b3",
    Type: "Profiled",
    "Cost ($/MW)": 120,
    "Maximum power (MW)": [50, 50, 50, 50, 50],
    "Minimum power (MW)": [0, 0, 0, 0, 0],
  });
});

test("changeThermalUnitData", () => {
  let scenario = TEST_DATA_1;
  let err: ValidationError | null;
  [scenario, err] = changeThermalUnitData(
    "g1",
    "Ramp up limit (MW)",
    "99",
    scenario,
  );
  assert(!err);
  [scenario, err] = changeThermalUnitData(
    "g1",
    "Startup costs ($) 2",
    "99",
    scenario,
  );
  assert(!err);
  [scenario, err] = changeThermalUnitData(
    "g1",
    "Production cost curve ($) 7",
    "99",
    scenario,
  );
  assert(!err);
  [scenario, err] = changeThermalUnitData(
    "g1",
    "Production cost curve (MW) 3",
    "",
    scenario,
  );
  assert(!err);
  [scenario, err] = changeThermalUnitData("g1", "Must run?", "true", scenario);
  assert(!err);
  assert.deepEqual(scenario.Generators["g1"], {
    Bus: "b1",
    Type: "Thermal",
    "Production cost curve (MW)": [100.0, 110],
    "Production cost curve ($)": [1400.0, 1600.0, 2200.0, 2400.0, 0, 0, 99],
    "Startup costs ($)": [300.0, 99.0],
    "Startup delays (h)": [1, 4],
    "Ramp up limit (MW)": 99,
    "Ramp down limit (MW)": 232.68,
    "Startup limit (MW)": 232.68,
    "Shutdown limit (MW)": 232.68,
    "Minimum downtime (h)": 4,
    "Minimum uptime (h)": 4,
    "Initial status (h)": 12,
    "Initial power (MW)": 115,
    "Must run?": true,
  });
});

test("changeProfiledUnitData with invalid bus", () => {
  let scenario = TEST_DATA_1;
  let err = null;
  [scenario, err] = changeProfiledUnitData("pu1", "Bus", "b99", scenario);
  assert(err !== null);
  assert.equal(err.message, 'Bus "b99" does not exist');
});

test("deleteGenerator", () => {
  const newScenario = deleteGenerator("pu1", TEST_DATA_1);
  assert.equal(Object.keys(newScenario.Generators).length, 2);
  assert("g1" in newScenario.Generators);
  assert("pu2" in newScenario.Generators);
});

test("renameGenerator", () => {
  const [newScenario, err] = renameGenerator("pu1", "pu5", TEST_DATA_1);
  assert(err === null);
  assert.deepEqual(newScenario.Generators["pu5"], {
    Bus: "b1",
    Type: "Profiled",
    "Cost ($/MW)": 12.5,
    "Maximum power (MW)": [10, 12, 13, 15, 20],
    "Minimum power (MW)": [0, 0, 0, 0, 0],
  });
  assert.deepEqual(newScenario.Generators["pu2"], {
    Bus: "b1",
    Type: "Profiled",
    "Cost ($/MW)": 120,
    "Maximum power (MW)": [50, 50, 50, 50, 50],
    "Minimum power (MW)": [0, 0, 0, 0, 0],
  });
});
