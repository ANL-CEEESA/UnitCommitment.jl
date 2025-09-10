/*
 * UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
 * Copyright (C) 2020-2025, UChicago Argonne, LLC. All rights reserved.
 * Released under the modified BSD license. See COPYING.md for more details.
 */

import {
  assertBusesNotEmpty,
  changeData,
  generateUniqueName,
  parseBool,
  renameItemInObject,
} from "./commonOps";
import { ValidationError } from "../Data/validate";
import { TransmissionLinesColumnSpec } from "../../components/CaseBuilder/TransmissionLines";
import {
  Contingency,
  TransmissionLine,
  UnitCommitmentScenario,
} from "../Data/types";

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

  // Update transmission line contingencies
  let newContingencies = scenario["Contingencies"];
  const contingencyLines = getContingencyTransmissionLines(scenario);
  if (contingencyLines.has(oldName)) {
    contingencyLines.delete(oldName);
    contingencyLines.add(newName);
    newContingencies = rebuildContingencies(contingencyLines);
  }

  return [
    {
      ...scenario,
      "Transmission lines": newLine,
      Contingencies: newContingencies,
    },
    null,
  ];
};

export const changeTransmissionLineData = (
  line: string,
  field: string,
  newValueStr: string,
  scenario: UnitCommitmentScenario,
): [UnitCommitmentScenario, ValidationError | null] => {
  if (field === "Contingency?") {
    // Parse boolean value
    const [newValue, err] = parseBool(newValueStr);
    if (err) return [scenario, err];

    // Rebuild contingencies
    const contLines = getContingencyTransmissionLines(scenario);
    if (newValue) contLines.add(line);
    else contLines.delete(line);
    const newContingencies = rebuildContingencies(contLines);

    return [{ ...scenario, Contingencies: newContingencies }, null];
  } else {
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
  }
};

export const deleteTransmissionLine = (
  name: string,
  scenario: UnitCommitmentScenario,
): UnitCommitmentScenario => {
  const { [name]: _, ...newLines } = scenario["Transmission lines"];

  // Update transmission line contingencies
  let newContingencies = scenario["Contingencies"];
  const contingencyLines = getContingencyTransmissionLines(scenario);
  if (contingencyLines.has(name)) {
    contingencyLines.delete(name);
    newContingencies = rebuildContingencies(contingencyLines);
  }

  return {
    ...scenario,
    "Transmission lines": newLines,
    Contingencies: newContingencies,
  };
};

export const getContingencyTransmissionLines = (
  scenario: UnitCommitmentScenario,
): Set<String> => {
  let result: Set<String> = new Set();
  Object.entries(scenario.Contingencies).forEach(([name, contingency]) => {
    if (contingency["Affected lines"].length !== 1)
      throw Error("not implemented");
    result.add(contingency["Affected lines"][0]!!);
  });
  return result;
};

export const rebuildContingencies = (
  contingencyLines: Set<String>,
): { [name: string]: Contingency } => {
  const result: { [name: string]: Contingency } = {};
  contingencyLines.forEach((lineName) => {
    result[lineName as string] = {
      "Affected lines": [lineName as string],
      "Affected generators": [],
    };
  });
  return result;
};
