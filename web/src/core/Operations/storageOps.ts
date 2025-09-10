/*
 * UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
 * Copyright (C) 2020-2025, UChicago Argonne, LLC. All rights reserved.
 * Released under the modified BSD license. See COPYING.md for more details.
 */

import { ValidationError } from "../Data/validate";
import { StorageUnit, UnitCommitmentScenario } from "../Data/types";
import {
  assertBusesNotEmpty,
  changeData,
  generateUniqueName,
  renameItemInObject,
} from "./commonOps";
import { StorageUnitsColumnSpec } from "../../components/CaseBuilder/StorageUnits";

export const createStorageUnit = (
  scenario: UnitCommitmentScenario,
): [UnitCommitmentScenario, ValidationError | null] => {
  const err = assertBusesNotEmpty(scenario);
  if (err) return [scenario, err];
  const busName = Object.keys(scenario.Buses)[0]!;
  const name = generateUniqueName(scenario["Storage units"], "su");
  return [
    {
      ...scenario,
      "Storage units": {
        ...scenario["Storage units"],
        [name]: {
          Bus: busName,
          "Minimum level (MWh)": 0,
          "Maximum level (MWh)": 1,
          "Charge cost ($/MW)": 0.0,
          "Discharge cost ($/MW)": 0.0,
          "Charge efficiency": 1,
          "Discharge efficiency": 1,
          "Loss factor": 0,
          "Minimum charge rate (MW)": 1,
          "Maximum charge rate (MW)": 1,
          "Minimum discharge rate (MW)": 1,
          "Maximum discharge rate (MW)": 1,
          "Initial level (MWh)": 0,
          "Last period minimum level (MWh)": 0,
          "Last period maximum level (MWh)": 1,
        },
      },
    },
    null,
  ];
};

export const renameStorageUnit = (
  oldName: string,
  newName: string,
  scenario: UnitCommitmentScenario,
): [UnitCommitmentScenario, ValidationError | null] => {
  const [newObj, err] = renameItemInObject(
    oldName,
    newName,
    scenario["Storage units"],
  );
  if (err) return [scenario, err];
  return [{ ...scenario, "Storage units": newObj }, null];
};

export const changeStorageUnitData = (
  name: string,
  field: string,
  newValueStr: string,
  scenario: UnitCommitmentScenario,
): [UnitCommitmentScenario, ValidationError | null] => {
  const [newObj, err] = changeData(
    field,
    newValueStr,
    scenario["Storage units"][name]!,
    StorageUnitsColumnSpec,
    scenario,
  );
  if (err) return [scenario, err];
  return [
    {
      ...scenario,
      "Storage units": {
        ...scenario["Storage units"],
        [name]: newObj as StorageUnit,
      },
    },
    null,
  ];
};

export const deleteStorageUnit = (
  name: string,
  scenario: UnitCommitmentScenario,
): UnitCommitmentScenario => {
  const { [name]: _, ...newContainer } = scenario["Storage units"];
  return { ...scenario, "Storage units": newContainer };
};
