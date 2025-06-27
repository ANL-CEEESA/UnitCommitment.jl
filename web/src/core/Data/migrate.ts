/*
 * UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
 * Copyright (C) 2020-2025, UChicago Argonne, LLC. All rights reserved.
 * Released under the modified BSD license. See COPYING.md for more details.
 */

import { ValidationError } from "./validate";

export const migrate = (json: any): ValidationError | null => {
  const version = json.Parameters?.Version;
  if (!version) {
    return {
      message:
        "The provided input file cannot be loaded because it does not " +
        "specify what version of UnitCommitment.jl it was written for.",
    };
  }
  if (!["0.2", "0.3", "0.4"].includes(version)) {
    return { message: `Unsupported file version: ${version}` };
  }
  if (version < "0.3") migrateToV03(json);
  if (version < "0.4") migrateToV04(json);
  json.Parameters.Version = "0.4";
  return null;
};

export const migrateToV03 = (json: any): void => {
  if (json.Reserves && json.Reserves["Spinning (MW)"] != null) {
    const amount = json.Reserves["Spinning (MW)"];
    json.Reserves = {
      r1: {
        Type: "spinning",
        "Amount (MW)": amount,
      },
    };
    if (json.Generators) {
      for (const genName in json.Generators) {
        const gen = json.Generators[genName];
        if (gen["Provides spinning reserves?"] === true) {
          gen["Reserve eligibility"] = ["r1"];
        }
      }
    }
  }
};

export const migrateToV04 = (json: any): void => {
  if (json.Generators) {
    for (const genName in json.Generators) {
      const gen = json.Generators[genName];
      if (gen.Type == null) {
        gen.Type = "Thermal";
      }
    }
  }
};
