/*
 * UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
 * Copyright (C) 2020-2025, UChicago Argonne, LLC. All rights reserved.
 * Released under the modified BSD license. See COPYING.md for more details.
 */

import assert from "node:assert";
import {
  BusesColumnSpec,
  generateBusesData,
} from "../../CaseBuilder/Buses/Buses";
import { generateCsv, parseCsv } from "./DataTable";
import { TEST_DATA_1 } from "../../../core/fixtures.test";
import { ProfiledUnitsColumnSpec } from "../../CaseBuilder/ProfiledUnits/ProfiledUnits";

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

test("parse CSV (Profiled Units)", () => {
  const csvContents =
    "Name,Bus,Cost ($/MW),Maximum power (MW) 00:00,Maximum power (MW) 01:00," +
    "Maximum power (MW) 02:00,Maximum power (MW) 03:00," +
    "Maximum power (MW) 04:00,Minimum power (MW) 00:00," +
    "Minimum power (MW) 01:00,Minimum power (MW) 02:00," +
    "Minimum power (MW) 03:00,Minimum power (MW) 04:00\n" +
    "pu1,b1,50,260.25384545,72.89148068,377.17886108,336.66732361," +
    "376.82781758,52.05076909,14.57829614,75.43577222,67.33346472,75.36556352\n" +
    "pu2,b1,0,0,0,0,0,0,0,0,0,0,0";
  const [newGenerators, err] = parseCsv(
    csvContents,
    ProfiledUnitsColumnSpec,
    TEST_DATA_1,
  );
  assert(err === null);
  assert.deepEqual(newGenerators, {
    pu1: {
      Bus: "b1",
      "Minimum power (MW)": [
        52.05076909, 14.57829614, 75.43577222, 67.33346472, 75.36556352,
      ],
      "Maximum power (MW)": [
        260.25384545, 72.89148068, 377.17886108, 336.66732361, 376.82781758,
      ],
      "Cost ($/MW)": 50.0,
    },
    pu2: {
      Bus: "b1",
      "Minimum power (MW)": [0, 0, 0, 0, 0],
      "Maximum power (MW)": [0, 0, 0, 0, 0],
      "Cost ($/MW)": 0.0,
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
