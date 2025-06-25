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

const assertBusesNotEmpty = (
  scenario: UnitCommitmentScenario,
): ValidationError | null => {
  if (Object.keys(scenario.Buses).length === 0)
    return { message: "Profiled unit requires an existing bus." };
  return null;
};

export const createProfiledUnit = (
  scenario: UnitCommitmentScenario,
): [UnitCommitmentScenario, ValidationError | null] => {
  const err = assertBusesNotEmpty(scenario);
  if (err) return [scenario, err];
  const busName = Object.keys(scenario.Buses)[0]!;
  const timeslots = generateTimeslots(scenario);
  const name = generateUniqueName(scenario.Generators, "pu");
  return [
    {
      ...scenario,
      Generators: {
        ...scenario.Generators,
        [name]: {
          Bus: busName,
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

export const createThermalUnit = (
  scenario: UnitCommitmentScenario,
): [UnitCommitmentScenario, ValidationError | null] => {
  const err = assertBusesNotEmpty(scenario);
  if (err) return [scenario, err];
  const busName = Object.keys(scenario.Buses)[0]!;
  const name = generateUniqueName(scenario.Generators, "g");
  return [
    {
      ...scenario,
      Generators: {
        ...scenario.Generators,
        [name]: {
          Bus: busName,
          Type: "Thermal",
          "Production cost curve (MW)": [0, 100],
          "Production cost curve ($)": [0, 10],
          "Startup costs ($)": [0],
          "Startup delays (h)": [1],
          "Ramp up limit (MW)": "",
          "Ramp down limit (MW)": "",
          "Startup limit (MW)": "",
          "Shutdown limit (MW)": "",
          "Minimum downtime (h)": 1,
          "Minimum uptime (h)": 1,
          "Initial status (h)": -24,
          "Initial power (MW)": 0,
          "Must run?": false,
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
