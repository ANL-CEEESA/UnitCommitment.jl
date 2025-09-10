/*
 * UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
 * Copyright (C) 2020-2025, UChicago Argonne, LLC. All rights reserved.
 * Released under the modified BSD license. See COPYING.md for more details.
 */

import { validate, ValidationError } from "../Data/validate";
import { UnitCommitmentScenario } from "../Data/types";
import { migrate } from "../Data/migrate";
import {
  getContingencyTransmissionLines,
  rebuildContingencies,
} from "./transmissionOps";

export const preprocess = (
  data: any,
): [UnitCommitmentScenario | null, ValidationError | null] => {
  // Make a copy of the original data
  let result = JSON.parse(JSON.stringify(data));

  // Run migration
  migrate(result);

  // Run JSON validation and assign default values
  if (!validate(result)) {
    console.error(validate.errors);
    return [
      null,
      { message: "Invalid JSON file. See console for more details." },
    ];
  }

  // Expand scalars into arrays
  // @ts-ignore
  const timeHorizon = result["Parameters"]["Time horizon (h)"];
  // @ts-ignore
  const timeStep = result["Parameters"]["Time step (min)"];
  const T = (timeHorizon * 60) / timeStep;
  for (const busName in result["Buses"]) {
    // @ts-ignore
    const busData = result["Buses"][busName];
    const busLoad = busData["Load (MW)"];
    if (typeof busLoad === "number") {
      busData["Load (MW)"] = Array(T).fill(busLoad);
    }
  }

  // Add optional fields
  for (let field of [
    "Buses",
    "Generators",
    "Storage units",
    "Price-sensitive loads",
    "Transmission lines",
    "Reserves",
    "Contingencies",
  ]) {
    if (!result[field]) {
      result[field] = {};
    }
  }

  const scenario = result as unknown as UnitCommitmentScenario;

  // Rebuild contingencies
  const contingencyLines = getContingencyTransmissionLines(scenario);
  scenario["Contingencies"] = rebuildContingencies(contingencyLines);

  return [scenario, null];
};
