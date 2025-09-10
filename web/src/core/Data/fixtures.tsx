/*
 * UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
 * Copyright (C) 2020-2025, UChicago Argonne, LLC. All rights reserved.
 * Released under the modified BSD license. See COPYING.md for more details.
 */

import { UnitCommitmentScenario } from "./types";

export interface Buses {
  [busName: string]: { "Load (MW)": number[] };
}

export const BLANK_SCENARIO: UnitCommitmentScenario = {
  Parameters: {
    Version: "0.4",
    "Power balance penalty ($/MW)": 1000.0,
    "Time horizon (h)": 24,
    "Time step (min)": 60,
  },
  Buses: {},
  Generators: {},
  "Transmission lines": {},
  "Storage units": {},
  "Price-sensitive loads": {},
};
