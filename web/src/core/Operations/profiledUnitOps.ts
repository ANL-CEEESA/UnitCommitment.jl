/*
 * UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
 * Copyright (C) 2020-2025, UChicago Argonne, LLC. All rights reserved.
 * Released under the modified BSD license. See COPYING.md for more details.
 */

import { UnitCommitmentScenario } from "../fixtures";
import { generateTimeslots } from "../../components/Common/Forms/DataTable";
import { generateUniqueName } from "./busOperations";
import { ValidationError } from "../Validation/validate";

export const createProfiledUnit = (
  scenario: UnitCommitmentScenario,
): [UnitCommitmentScenario, ValidationError | null] => {
  const busNames = Object.keys(scenario.Buses);
  if (busNames.length === 0) {
    return [scenario, { message: "Profiled unit requires an existing bus." }];
  }
  const timeslots = generateTimeslots(scenario);
  const name = generateUniqueName(scenario.Generators, "pu");
  return [
    {
      ...scenario,
      Generators: {
        ...scenario.Generators,
        [name]: {
          Bus: busNames[0]!,
          Type: "Profiled",
          "Cost ($/MW)": 0,
          "Minimum power (MW)": Array(timeslots.length).fill(0),
          "Maximum power (MW)": Array(timeslots.length).fill(0),
        },
      },
    },
    null,
  ];
};
