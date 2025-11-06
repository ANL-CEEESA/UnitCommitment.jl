/*
 * UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
 * Copyright (C) 2020-2025, UChicago Argonne, LLC. All rights reserved.
 * Released under the modified BSD license. See COPYING.md for more details.
 */

import { ValidationError } from "../Data/validate";
import { PriceSensitiveLoad, UnitCommitmentScenario } from "../Data/types";
import {
  assertBusesNotEmpty,
  changeData,
  generateUniqueName,
  renameItemInObject,
} from "./commonOps";
import { PriceSensitiveLoadsColumnSpec } from "../../components/CaseBuilder/Psload";
import { generateTimeslots } from "../../components/Common/Forms/DataTable";

export const createPriceSensitiveLoad = (
  scenario: UnitCommitmentScenario,
): [UnitCommitmentScenario, ValidationError | null] => {
  const err = assertBusesNotEmpty(scenario);
  if (err) return [scenario, err];
  const busName = Object.keys(scenario.Buses)[0]!;
  const timeslots = generateTimeslots(scenario);
  const name = generateUniqueName(scenario["Price-sensitive loads"], "ps");
  return [
    {
      ...scenario,
      "Price-sensitive loads": {
        ...scenario["Price-sensitive loads"],
        [name]: {
          Bus: busName,
          "Revenue ($/MW)": 0,
          "Demand (MW)": Array(timeslots.length).fill(0),
        },
      },
    },
    null,
  ];
};

export const renamePriceSensitiveLoad = (
  oldName: string,
  newName: string,
  scenario: UnitCommitmentScenario,
): [UnitCommitmentScenario, ValidationError | null] => {
  const [newObj, err] = renameItemInObject(
    oldName,
    newName,
    scenario["Price-sensitive loads"],
  );
  if (err) return [scenario, err];
  return [{ ...scenario, "Price-sensitive loads": newObj }, null];
};

export const changePriceSensitiveLoadData = (
  name: string,
  field: string,
  newValueStr: string,
  scenario: UnitCommitmentScenario,
): [UnitCommitmentScenario, ValidationError | null] => {
  const [newObj, err] = changeData(
    field,
    newValueStr,
    scenario["Price-sensitive loads"][name]!,
    PriceSensitiveLoadsColumnSpec,
    scenario,
  );
  if (err) return [scenario, err];
  return [
    {
      ...scenario,
      "Price-sensitive loads": {
        ...scenario["Price-sensitive loads"],
        [name]: newObj as PriceSensitiveLoad,
      },
    },
    null,
  ];
};

export const deletePriceSensitiveLoad = (
  name: string,
  scenario: UnitCommitmentScenario,
): UnitCommitmentScenario => {
  const { [name]: _, ...newContainer } = scenario["Price-sensitive loads"];
  return { ...scenario, "Price-sensitive loads": newContainer };
};
