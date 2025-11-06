/*
 * UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
 * Copyright (C) 2020-2025, UChicago Argonne, LLC. All rights reserved.
 * Released under the modified BSD license. See COPYING.md for more details.
 */

import { Buses } from "../Data/fixtures";
import { ValidationError } from "../Data/validate";
import { generateTimeslots } from "../../components/Common/Forms/DataTable";
import {
  changeData,
  generateUniqueName,
  renameItemInObject,
} from "./commonOps";
import { BusesColumnSpec } from "../../components/CaseBuilder/Buses";
import { UnitCommitmentScenario } from "../Data/types";

export const createBus = (scenario: UnitCommitmentScenario) => {
  const name = generateUniqueName(scenario.Buses, "b");
  const timeslots = generateTimeslots(scenario);
  return {
    ...scenario,
    Buses: {
      ...scenario.Buses,
      [name]: {
        "Load (MW)": Array(timeslots.length).fill(0),
      },
    },
  };
};

export const changeBusData = (
  bus: string,
  field: string,
  newValueStr: string,
  scenario: UnitCommitmentScenario,
): [UnitCommitmentScenario, ValidationError | null] => {
  const [newBus, err] = changeData(
    field,
    newValueStr,
    scenario.Buses[bus]!,
    BusesColumnSpec,
    scenario,
  );
  if (err) return [scenario, err];
  return [
    {
      ...scenario,
      Buses: {
        ...scenario.Buses,
        [bus]: newBus,
      } as Buses,
    },
    null,
  ];
};

export const deleteBus = (bus: string, scenario: UnitCommitmentScenario) => {
  const { [bus]: _, ...newBuses } = scenario.Buses;
  const newGenerators = { ...scenario.Generators };

  // Update generators
  for (const genName in scenario.Generators) {
    let gen = scenario.Generators[genName]!;
    if (gen["Bus"] === bus) delete newGenerators[genName];
  }
  return { ...scenario, Buses: newBuses, Generators: newGenerators };
};

export const renameBus = (
  oldName: string,
  newName: string,
  scenario: UnitCommitmentScenario,
): [UnitCommitmentScenario, ValidationError | null] => {
  const [newBuses, err] = renameItemInObject(oldName, newName, scenario.Buses);
  if (err) return [scenario, err];

  // Update generators
  const newGenerators = { ...scenario.Generators };
  for (const genName in scenario.Generators) {
    let gen = newGenerators[genName]!;
    if (gen["Bus"] === oldName) {
      newGenerators[genName] = { ...gen, Bus: newName };
    }
  }
  return [{ ...scenario, Buses: newBuses, Generators: newGenerators }, null];
};
