/*
 * UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
 * Copyright (C) 2020-2025, UChicago Argonne, LLC. All rights reserved.
 * Released under the modified BSD license. See COPYING.md for more details.
 */

import { parseBool } from "./commonOps";
import assert from "node:assert";

test("parseBool", () => {
  // True values
  for (const str of ["true", "TRUE", "1"]) {
    let [v, err] = parseBool(str);
    assert(!err);
    assert.equal(v, true);
  }

  // False values
  for (const str of ["false", "FALSE", "0"]) {
    let [v, err] = parseBool(str);
    assert(!err);
    assert.equal(v, false);
  }

  // Invalid values
  for (const str of ["qwe", ""]) {
    let [, err] = parseBool(str);
    assert(err);
  }
});
