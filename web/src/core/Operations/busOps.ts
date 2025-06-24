/*
 * UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
 * Copyright (C) 2020-2025, UChicago Argonne, LLC. All rights reserved.
 * Released under the modified BSD license. See COPYING.md for more details.
 */

import { Buses, UnitCommitmentScenario } from "../fixtures";
import { ValidationError } from "../Validation/validate";
import { generateTimeslots } from "../../components/Common/Forms/DataTable";
import {
  changeData,
  generateUniqueName,
  renameItemInObject,
} from "./commonOps";
import { BusesColumnSpec } from "../../components/CaseBuilder/Buses/Buses";

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
  return { ...scenario, Buses: newBuses };
};

export const renameBus = (
  oldName: string,
  newName: string,
  scenario: UnitCommitmentScenario,
): [UnitCommitmentScenario, ValidationError | null] => {
  const [newBuses, err] = renameItemInObject(oldName, newName, scenario.Buses);
  if (err) return [scenario, err];
  return [{ ...scenario, Buses: newBuses }, null];
};
