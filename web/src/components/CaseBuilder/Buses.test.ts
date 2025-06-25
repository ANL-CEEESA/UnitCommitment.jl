/*
 * UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
 * Copyright (C) 2020-2025, UChicago Argonne, LLC. All rights reserved.
 * Released under the modified BSD license. See COPYING.md for more details.
 */

import assert from "node:assert";
import { BusesColumnSpec, generateBusesData } from "./Buses";
import { generateCsv, parseCsv } from "../Common/Forms/DataTable";
import { TEST_DATA_1 } from "../../core/fixtures.test";

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

test("parse CSV", () => {
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
