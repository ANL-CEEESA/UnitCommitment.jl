/*
 * UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
 * Copyright (C) 2020-2025, UChicago Argonne, LLC. All rights reserved.
 * Released under the modified BSD license. See COPYING.md for more details.
 */

import {
  assertBusesNotEmpty,
  changeData,
  generateUniqueName,
  renameItemInObject,
} from "./commonOps";
import { ValidationError } from "../Data/validate";
import { TransmissionLinesColumnSpec } from "../../components/CaseBuilder/TransmissionLines";
import { TransmissionLine, UnitCommitmentScenario } from "../Data/types";

export const createTransmissionLine = (
  scenario: UnitCommitmentScenario,
): [UnitCommitmentScenario, ValidationError | null] => {
  const err = assertBusesNotEmpty(scenario);
  if (err) return [scenario, err];
  const busName = Object.keys(scenario.Buses)[0]!;
  const name = generateUniqueName(scenario["Transmission lines"], "l");
  return [
    {
      ...scenario,
      "Transmission lines": {
        ...scenario["Transmission lines"],
        [name]: {
          "Source bus": busName,
          "Target bus": busName,
          "Susceptance (S)": 1.0,
          "Normal flow limit (MW)": 1000,
          "Emergency flow limit (MW)": 1500,
          "Flow limit penalty ($/MW)": 5000.0,
        },
      },
    },
    null,
  ];
};

export const renameTransmissionLine = (
  oldName: string,
  newName: string,
  scenario: UnitCommitmentScenario,
): [UnitCommitmentScenario, ValidationError | null] => {
  const [newLine, err] = renameItemInObject(
    oldName,
    newName,
    scenario["Transmission lines"],
  );
  if (err) return [scenario, err];
  return [{ ...scenario, "Transmission lines": newLine }, null];
};

export const changeTransmissionLineData = (
  line: string,
  field: string,
  newValueStr: string,
  scenario: UnitCommitmentScenario,
): [UnitCommitmentScenario, ValidationError | null] => {
  const [newLine, err] = changeData(
    field,
    newValueStr,
    scenario["Transmission lines"][line]!,
    TransmissionLinesColumnSpec,
    scenario,
  );
  if (err) return [scenario, err];
  return [
    {
      ...scenario,
      "Transmission lines": {
        ...scenario["Transmission lines"],
        [line]: newLine as TransmissionLine,
      },
    },
    null,
  ];
};

export const deleteTransmissionLine = (
  name: string,
  scenario: UnitCommitmentScenario,
): UnitCommitmentScenario => {
  const { [name]: _, ...newLines } = scenario["Transmission lines"];
  return { ...scenario, "Transmission lines": newLines };
};
