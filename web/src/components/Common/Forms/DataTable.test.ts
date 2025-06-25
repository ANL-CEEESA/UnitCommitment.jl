/*
 * UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
 * Copyright (C) 2020-2025, UChicago Argonne, LLC. All rights reserved.
 * Released under the modified BSD license. See COPYING.md for more details.
 */

import assert from "node:assert";
import { BusesColumnSpec, generateBusesData } from "../../CaseBuilder/Buses";
import {
  floatFormatter,
  generateCsv,
  generateTableColumns,
  generateTableData,
  parseCsv,
} from "./DataTable";
import { TEST_DATA_1 } from "../../../core/fixtures.test";
import { ThermalUnitsColumnSpec } from "../../CaseBuilder/ThermalUnits";
import { getThermalGenerators } from "../../../core/fixtures";

test("generateTableColumns (ThermalUnits)", () => {
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
    minWidth: 60,
    resizable: false,
    title: "1",
  });
});

test("generateTableData (ThermalUnits)", () => {
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

test("generate CSV", () => {
  const [data, columns] = generateBusesData(TEST_DATA_1);
  const actualCsv = generateCsv(data, columns);
  const expectedCsv =
    "Name,Load (MW) 00:00,Load (MW) 01:00,Load (MW) 02:00,Load (MW) 03:00,Load (MW) 04:00\n" +
    "b1,35.79534,34.38835,33.45083,32.89729,33.25044\n" +
    "b2,14.03739,13.48563,13.11797,12.9009,13.03939\n" +
    "b3,27.3729,26.29698,25.58005,25.15675,25.4268";
  assert.strictEqual(actualCsv, expectedCsv);
});

test("parse CSV (Buses)", () => {
  const csvContents =
    "Name,Load (MW) 00:00,Load (MW) 01:00,Load (MW) 02:00,Load (MW) 03:00,Load (MW) 04:00\n" +
    "b1,0,1,2,3,4\n" +
    "b3,27.3729,26.29698,25.58005,25.15675,25.4268";
  const [newBuses, err] = parseCsv(csvContents, BusesColumnSpec, TEST_DATA_1);
  assert(err === null);
  assert.deepEqual(newBuses, {
    b1: {
      "Load (MW)": [0, 1, 2, 3, 4],
    },
    b3: {
      "Load (MW)": [27.3729, 26.29698, 25.58005, 25.15675, 25.4268],
    },
  });
});

test("parse CSV with duplicated names", () => {
  const csvContents =
    "Name,Load (MW) 00:00,Load (MW) 01:00,Load (MW) 02:00,Load (MW) 03:00,Load (MW) 04:00\n" +
    "b1,0,0,0,0,0\n" +
    "b1,0,0,0,0,0";
  const [, err] = parseCsv(csvContents, BusesColumnSpec, TEST_DATA_1);
  assert(err !== null);
  assert.equal(err.message, `Name "b1" is duplicated (row 2)`);
});
