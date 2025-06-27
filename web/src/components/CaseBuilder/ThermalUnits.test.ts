/*
 * UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
 * Copyright (C) 2020-2025, UChicago Argonne, LLC. All rights reserved.
 * Released under the modified BSD license. See COPYING.md for more details.
 */

import {
  floatFormatter,
  generateCsv,
  generateTableColumns,
  generateTableData,
} from "../Common/Forms/DataTable";
import { TEST_DATA_1 } from "../../core/fixtures.test";
import {
  generateThermalUnitsData,
  parseThermalUnitsCsv,
  ThermalUnitsColumnSpec,
} from "./ThermalUnits";
import assert from "node:assert";
import {
  getProfiledGenerators,
  getThermalGenerators,
} from "../../core/fixtures";

test("generateTableColumns", () => {
  const columns = generateTableColumns(TEST_DATA_1, ThermalUnitsColumnSpec);
  assert.equal(columns[2]!["columns"]!.length, 10);
  assert.deepEqual(columns[2]!["columns"]![0], {
    editor: "input",
    editorParams: {
      selectContents: true,
    },
    field: "Production cost curve (MW) 1",
    formatter: floatFormatter,
    headerHozAlign: "left",
    headerSort: false,
    headerWordWrap: true,
    hozAlign: "left",
    minWidth: 75,
    resizable: false,
    title: "1",
  });
});

test("generateTableData", () => {
  const data = generateTableData(
    getThermalGenerators(TEST_DATA_1),
    ThermalUnitsColumnSpec,
    TEST_DATA_1,
  );
  assert.deepEqual(data[0], {
    Name: "g1",
    Bus: "b1",
    "Initial power (MW)": 115,
    "Initial status (h)": 12,
    "Minimum downtime (h)": 4,
    "Minimum uptime (h)": 4,
    "Ramp down limit (MW)": 232.68,
    "Ramp up limit (MW)": 232.68,
    "Shutdown limit (MW)": 232.68,
    "Startup limit (MW)": 232.68,
    "Production cost curve ($) 1": 1400,
    "Production cost curve ($) 2": 1600,
    "Production cost curve ($) 3": 2200,
    "Production cost curve ($) 4": 2400,
    "Production cost curve ($) 5": "",
    "Production cost curve ($) 6": "",
    "Production cost curve ($) 7": "",
    "Production cost curve ($) 8": "",
    "Production cost curve ($) 9": "",
    "Production cost curve ($) 10": "",
    "Production cost curve (MW) 1": 100,
    "Production cost curve (MW) 2": 110,
    "Production cost curve (MW) 3": 130,
    "Production cost curve (MW) 4": 135,
    "Production cost curve (MW) 5": "",
    "Production cost curve (MW) 6": "",
    "Production cost curve (MW) 7": "",
    "Production cost curve (MW) 8": "",
    "Production cost curve (MW) 9": "",
    "Production cost curve (MW) 10": "",
    "Startup costs ($) 1": 300,
    "Startup costs ($) 2": 400,
    "Startup costs ($) 3": "",
    "Startup costs ($) 4": "",
    "Startup costs ($) 5": "",
    "Startup delays (h) 1": 1,
    "Startup delays (h) 2": 4,
    "Startup delays (h) 3": "",
    "Startup delays (h) 4": "",
    "Startup delays (h) 5": "",
    "Must run?": false,
  });
});

const expectedCsvContents =
  "Name,Bus," +
  "Production cost curve (MW) 1," +
  "Production cost curve (MW) 2," +
  "Production cost curve (MW) 3," +
  "Production cost curve (MW) 4," +
  "Production cost curve (MW) 5," +
  "Production cost curve (MW) 6," +
  "Production cost curve (MW) 7," +
  "Production cost curve (MW) 8," +
  "Production cost curve (MW) 9," +
  "Production cost curve (MW) 10," +
  "Production cost curve ($) 1," +
  "Production cost curve ($) 2," +
  "Production cost curve ($) 3," +
  "Production cost curve ($) 4," +
  "Production cost curve ($) 5," +
  "Production cost curve ($) 6," +
  "Production cost curve ($) 7," +
  "Production cost curve ($) 8," +
  "Production cost curve ($) 9," +
  "Production cost curve ($) 10," +
  "Startup costs ($) 1," +
  "Startup costs ($) 2," +
  "Startup costs ($) 3," +
  "Startup costs ($) 4," +
  "Startup costs ($) 5," +
  "Startup delays (h) 1," +
  "Startup delays (h) 2," +
  "Startup delays (h) 3," +
  "Startup delays (h) 4," +
  "Startup delays (h) 5," +
  "Minimum uptime (h),Minimum downtime (h),Ramp up limit (MW)," +
  "Ramp down limit (MW),Startup limit (MW),Shutdown limit (MW)," +
  "Initial status (h),Initial power (MW),Must run?\n" +
  "g1,b1,100,110,130,135,,,,,,,1400,1600,2200,2400,,,,,,,300,400,,,,1,4,,,,4,4,232.68,232.68,232.68,232.68,12,115,false";

const invalidCsv =
  "Name,Bus," +
  "Production cost curve (MW) 1," +
  "Production cost curve (MW) 2," +
  "Production cost curve (MW) 3," +
  "Production cost curve (MW) 4," +
  "Production cost curve (MW) 5," +
  "Production cost curve (MW) 6," +
  "Production cost curve (MW) 7," +
  "Production cost curve (MW) 8," +
  "Production cost curve (MW) 9," +
  "Production cost curve (MW) 10," +
  "Production cost curve ($) 1," +
  "Production cost curve ($) 2," +
  "Production cost curve ($) 3," +
  "Production cost curve ($) 4," +
  "Production cost curve ($) 5," +
  "Production cost curve ($) 6," +
  "Production cost curve ($) 7," +
  "Production cost curve ($) 8," +
  "Production cost curve ($) 9," +
  "Production cost curve ($) 10," +
  "Startup costs ($) 1," +
  "Startup costs ($) 2," +
  "Startup costs ($) 3," +
  "Startup costs ($) 4," +
  "Startup costs ($) 5," +
  "Startup delays (h) 1," +
  "Startup delays (h) 2," +
  "Startup delays (h) 3," +
  "Startup delays (h) 4," +
  "Startup delays (h) 5," +
  "Minimum uptime (h),Minimum downtime (h),Ramp up limit (MW)," +
  "Ramp down limit (MW),Startup limit (MW),Shutdown limit (MW)," +
  "Initial status (h),Initial power (MW),Must run?\n" +
  "g1,b1,100,110,130,x,,,,,,,1400,1600,2200,2400,,,,,,,300,400,,,,1,4,,,,4,4,232.68,232.68,232.68,232.68,12,115,false";

test("generateCSV", () => {
  const [data, columns] = generateThermalUnitsData(TEST_DATA_1);
  const actualCsvContents = generateCsv(data, columns);
  assert.equal(actualCsvContents, expectedCsvContents);
});

test("parseCSV", () => {
  const [scenario, err] = parseThermalUnitsCsv(
    expectedCsvContents,
    TEST_DATA_1,
  );
  assert(!err);
  const thermalGens = getThermalGenerators(scenario);
  const profGens = getProfiledGenerators(scenario);
  assert.equal(Object.keys(thermalGens).length, 1);
  assert.equal(Object.keys(profGens).length, 2);
  assert.deepEqual(thermalGens["g1"], {
    Bus: "b1",
    Type: "Thermal",
    "Production cost curve (MW)": [100.0, 110.0, 130.0, 135.0],
    "Production cost curve ($)": [1400.0, 1600.0, 2200.0, 2400.0],
    "Startup costs ($)": [300.0, 400.0],
    "Startup delays (h)": [1, 4],
    "Ramp up limit (MW)": 232.68,
    "Ramp down limit (MW)": 232.68,
    "Startup limit (MW)": 232.68,
    "Shutdown limit (MW)": 232.68,
    "Minimum downtime (h)": 4,
    "Minimum uptime (h)": 4,
    "Initial status (h)": 12,
    "Initial power (MW)": 115,
    "Must run?": false,
  });
});

test("parseCSV with invalid number[T]", () => {
  const [, err] = parseThermalUnitsCsv(invalidCsv, TEST_DATA_1);
  assert(err);
  assert.equal(err.message, '"x" is not a valid number (row 1)');
});
