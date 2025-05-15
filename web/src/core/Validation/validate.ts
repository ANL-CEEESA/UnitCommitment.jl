/*
 * UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
 * Copyright (C) 2020-2025, UChicago Argonne, LLC. All rights reserved.
 * Released under the modified BSD license. See COPYING.md for more details.
 */

import { schema } from "./schema";
import Ajv from "ajv";

// Create Ajv instance with detailed debug options
const ajv = new Ajv({
  verbose: true,
  allErrors: true,
  $data: true,
});

export interface ValidationError {
  message: string;
}

export const validate = ajv.compile(schema);
