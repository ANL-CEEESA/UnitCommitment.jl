/*
 * UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
 * Copyright (C) 2020-2025, UChicago Argonne, LLC. All rights reserved.
 * Released under the modified BSD license. See COPYING.md for more details.
 */

import assert from "node:assert";
import { generateBusesCsv, parseBusesCsv } from "./BusesTable";
import { BUS_TEST_DATA_1 } from "../../core/Operations/busOperations.test";

test("generate CSV", () => {
  const actualCsv = generateBusesCsv(BUS_TEST_DATA_1);
  const expectedCsv =
    "Name,Load 0,Load 1,Load 2,Load 3,Load 4\n" +
    "b1,35.79534,34.38835,33.45083,32.89729,33.25044\n" +
    "b2,14.03739,13.48563,13.11797,12.9009,13.03939\n" +
    "b3,27.3729,26.29698,25.58005,25.15675,25.4268";
  assert.strictEqual(actualCsv, expectedCsv);
});

test("parse valid CSV", () => {
  const csvContents =
    "Name,Load 0,Load 1,Load 2,Load 3,Load 4\n" +
    "b1,0,1,2,3,4\n" +
    "b3,27.3729,26.29698,25.58005,25.15675,25.4268";
  const newScenario = parseBusesCsv(BUS_TEST_DATA_1, csvContents);
  assert.deepEqual(newScenario.Buses, {
    b1: {
      "Load (MW)": [0, 1, 2, 3, 4],
    },
    b3: {
      "Load (MW)": [27.3729, 26.29698, 25.58005, 25.15675, 25.4268],
    },
  });
});

test("parse invalid CSV (wrong headers)", () => {
  const csvContents =
    "Name,Load 5,Load 7,Load 23,Load 3,Load 4\n" +
    "b1,0,1,2,3,4\n" +
    "b3,27.3729,26.29698,25.58005,25.15675,25.4268";
  expect(() => {
    parseBusesCsv(BUS_TEST_DATA_1, csvContents);
  }).toThrow(Error);
});

test("parse invalid CSV (wrong data length)", () => {
  const csvContents =
    "Name,Load 0,Load 1,Load 2,Load 3,Load 4\n" +
    "b1,0,1,2,3\n" +
    "b3,27.3729,26.29698,25.58005,25.15675,25.4268";
  expect(() => {
    parseBusesCsv(BUS_TEST_DATA_1, csvContents);
  }).toThrow(Error);
});
