/*
 * UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
 * Copyright (C) 2020-2025, UChicago Argonne, LLC. All rights reserved.
 * Released under the modified BSD license. See COPYING.md for more details.
 */

import {
  floatFormatter,
  generateTableColumns,
  parseCsv,
} from "../Common/Forms/DataTable";
import {
  parseProfiledUnitsCsv,
  ProfiledUnitsColumnSpec,
} from "./ProfiledUnits";
import { TEST_DATA_1 } from "../../core/Data/fixtures.test";
import assert from "node:assert";
import {
  getProfiledGenerators,
  getThermalGenerators,
} from "../../core/Data/types";

test("parse CSV", () => {
  const csvContents =
    "Name,Bus,Cost ($/MW),Maximum power (MW) 00:00,Maximum power (MW) 01:00," +
    "Maximum power (MW) 02:00,Maximum power (MW) 03:00," +
    "Maximum power (MW) 04:00,Minimum power (MW) 00:00," +
    "Minimum power (MW) 01:00,Minimum power (MW) 02:00," +
    "Minimum power (MW) 03:00,Minimum power (MW) 04:00\n" +
    "pu1,b1,50,260.25384545,72.89148068,377.17886108,336.66732361," +
    "376.82781758,52.05076909,14.57829614,75.43577222,67.33346472,75.36556352\n" +
    "pu2,b1,0,0,0,0,0,0,0,0,0,0,0";
  const [scenario, err] = parseProfiledUnitsCsv(csvContents, TEST_DATA_1);
  assert(err === null);
  const thermalGens = getThermalGenerators(scenario);
  const profGens = getProfiledGenerators(scenario);
  assert.equal(Object.keys(thermalGens).length, 1);
  assert.equal(Object.keys(profGens).length, 2);

  assert.deepEqual(profGens, {
    pu1: {
      Bus: "b1",
      "Minimum power (MW)": [
        52.05076909, 14.57829614, 75.43577222, 67.33346472, 75.36556352,
      ],
      "Maximum power (MW)": [
        260.25384545, 72.89148068, 377.17886108, 336.66732361, 376.82781758,
      ],
      "Cost ($/MW)": 50.0,
      Type: "Profiled",
    },
    pu2: {
      Bus: "b1",
      "Minimum power (MW)": [0, 0, 0, 0, 0],
      "Maximum power (MW)": [0, 0, 0, 0, 0],
      "Cost ($/MW)": 0.0,
      Type: "Profiled",
    },
  });
});

test("parse CSV with invalid bus", () => {
  const csvContents =
    "Name,Bus,Cost ($/MW),Maximum power (MW) 00:00,Maximum power (MW) 01:00," +
    "Maximum power (MW) 02:00,Maximum power (MW) 03:00," +
    "Maximum power (MW) 04:00,Minimum power (MW) 00:00," +
    "Minimum power (MW) 01:00,Minimum power (MW) 02:00," +
    "Minimum power (MW) 03:00,Minimum power (MW) 04:00\n" +
    "pu1,b99,50,260.25384545,72.89148068,377.17886108,336.66732361," +
    "376.82781758,52.05076909,14.57829614,75.43577222,67.33346472,75.36556352\n" +
    "pu2,b1,0,0,0,0,0,0,0,0,0,0,0";
  const [, err] = parseCsv(csvContents, ProfiledUnitsColumnSpec, TEST_DATA_1);
  assert(err !== null);
  assert.equal(err.message, 'Bus "b99" does not exist (row 1)');
});

test("generateTableColumns", () => {
  const columns = generateTableColumns(TEST_DATA_1, ProfiledUnitsColumnSpec);
  assert.equal(columns.length, 5);
  assert.deepEqual(columns[0], {
    editor: "input",
    editorParams: {
      selectContents: true,
    },
    field: "Name",
    formatter: "plaintext",
    headerHozAlign: "left",
    headerSort: false,
    headerWordWrap: true,
    hozAlign: "left",
    minWidth: 100,
    resizable: false,
    title: "Name",
  });
  assert.equal(columns[3]!["columns"]!.length, 5);
  assert.deepEqual(columns[3]!["columns"]![0], {
    editor: "input",
    editorParams: {
      selectContents: true,
    },
    field: "Maximum power (MW) 00:00",
    formatter: floatFormatter,
    headerHozAlign: "left",
    headerSort: false,
    headerWordWrap: true,
    hozAlign: "left",
    minWidth: 75,
    resizable: false,
    title: "00:00",
  });
});
