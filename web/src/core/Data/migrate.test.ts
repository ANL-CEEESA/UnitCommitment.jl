/*
 * UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
 * Copyright (C) 2020-2025, UChicago Argonne, LLC. All rights reserved.
 * Released under the modified BSD license. See COPYING.md for more details.
 */

import assert from "node:assert";
import fs from "node:fs";
import pako from "pako";
import { migrateToV03, migrateToV04 } from "./migrate";

function readJsonGz(filename: string) {
  const compressedData = fs.readFileSync(filename);
  const decompressedData = pako.inflate(compressedData, { to: "string" });
  return JSON.parse(decompressedData);
}

test("migrateToV03", () => {
  const jsonData = readJsonGz("../test/fixtures/ucjl-0.2.json.gz");
  migrateToV03(jsonData);
  assert.deepEqual(jsonData.Reserves, {
    r1: {
      "Amount (MW)": 100,
      "Shortfall penalty ($/MW)": 1000,
      Type: "spinning",
    },
  });
});

test("migrateToV04", () => {
  const jsonData = readJsonGz("../test/fixtures/ucjl-0.3.json.gz");
  migrateToV04(jsonData);
  assert.equal(jsonData.Generators["g1"].Type, "Thermal");
});
