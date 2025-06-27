// @ts-nocheck

/*
 * UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
 * Copyright (C) 2020-2025, UChicago Argonne, LLC. All rights reserved.
 * Released under the modified BSD license. See COPYING.md for more details.
 */

import { validate } from "../Data/validate";

export const preprocess = (data) => {
  // Make a copy of the original data
  let result = JSON.parse(JSON.stringify(data));

  // Run JSON validation and assign default values
  if (!validate(result)) {
    console.error(validate.errors);
    throw Error("Invalid JSON");
  }

  // Expand scalars into arrays
  const timeHorizon = result["Parameters"]["Time horizon (h)"];
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
  return result;
};
