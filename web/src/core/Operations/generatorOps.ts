/*
 * UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
 * Copyright (C) 2020-2025, UChicago Argonne, LLC. All rights reserved.
 * Released under the modified BSD license. See COPYING.md for more details.
 */

import { Generators, UnitCommitmentScenario } from "../fixtures";
import { generateTimeslots } from "../../components/Common/Forms/DataTable";
import { ValidationError } from "../Validation/validate";
import {
  changeData,
  generateUniqueName,
  renameItemInObject,
} from "./commonOps";
import { ProfiledUnitsColumnSpec } from "../../components/CaseBuilder/ProfiledUnits";

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

export const changeProfiledUnitData = (
  generator: string,
  field: string,
  newValueStr: string,
  scenario: UnitCommitmentScenario,
): [UnitCommitmentScenario, ValidationError | null] => {
  const [newGen, err] = changeData(
    field,
    newValueStr,
    scenario.Generators[generator]!,
    ProfiledUnitsColumnSpec,
    scenario,
  );
  if (err) return [scenario, err];
  return [
    {
      ...scenario,
      Generators: {
        ...scenario.Generators,
        [generator]: newGen,
      } as Generators,
    },
    null,
  ];
};

export const deleteGenerator = (
  name: string,
  scenario: UnitCommitmentScenario,
): UnitCommitmentScenario => {
  const { [name]: _, ...newGenerators } = scenario.Generators;
  return { ...scenario, Generators: newGenerators };
};

export const renameGenerator = (
  oldName: string,
  newName: string,
  scenario: UnitCommitmentScenario,
): [UnitCommitmentScenario, ValidationError | null] => {
  const [newGen, err] = renameItemInObject(
    oldName,
    newName,
    scenario.Generators,
  );
  if (err) return [scenario, err];
  return [{ ...scenario, Generators: newGen }, null];
};
