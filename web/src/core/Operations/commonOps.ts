/*
 * UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
 * Copyright (C) 2020-2025, UChicago Argonne, LLC. All rights reserved.
 * Released under the modified BSD license. See COPYING.md for more details.
 */

import { ValidationError } from "../Validation/validate";
import { UnitCommitmentScenario } from "../fixtures";
import { ColumnSpec } from "../../components/Common/Forms/DataTable";

export const renameItemInObject = <T>(
  oldName: string,
  newName: string,
  container: { [key: string]: T },
): [{ [key: string]: T }, ValidationError | null] => {
  if (newName in container) {
    return [container, { message: `${newName} already exists` }];
  }
  const newContainer = Object.keys(container).reduce(
    (acc, val) => {
      if (val === oldName) {
        acc[newName] = container[val]!;
      } else {
        acc[val] = container[val]!;
      }
      return acc;
    },
    {} as { [key: string]: T },
  );
  return [newContainer, null];
};

export const generateUniqueName = (container: any, prefix: string): string => {
  let counter = 1;
  let name = `${prefix}${counter}`;
  while (name in container) {
    counter++;
    name = `${prefix}${counter}`;
  }
  return name;
};

const parseNumber = (valueStr: string): [number, ValidationError | null] => {
  const valueFloat = parseFloat(valueStr);
  if (isNaN(valueFloat)) {
    return [0, { message: `"${valueStr}" is not a valid number` }];
  } else {
    return [valueFloat, null];
  }
};

export const changeStringData = (
  field: string,
  newValue: string,
  container: { [key: string]: any },
): [{ [key: string]: any }, ValidationError | null] => {
  return [
    {
      ...container,
      [field]: newValue,
    },
    null,
  ];
};

export const changeBusRefData = (
  field: string,
  newValue: string,
  container: { [key: string]: any },
  scenario: UnitCommitmentScenario,
): [{ [key: string]: any }, ValidationError | null] => {
  if (!(newValue in scenario.Buses)) {
    return [scenario, { message: `Bus "${newValue}" does not exist` }];
  }
  return changeStringData(field, newValue, container);
};

export const changeNumberData = (
  field: string,
  newValueStr: string,
  container: { [key: string]: any },
): [{ [key: string]: any }, ValidationError | null] => {
  // Parse value
  const [newValueFloat, err] = parseNumber(newValueStr);
  if (err) return [container, err];

  // Build the new object
  return [
    {
      ...container,
      [field]: newValueFloat,
    },
    null,
  ];
};

export const changeNumberVecData = (
  field: string,
  time: string,
  newValueStr: string,
  container: { [key: string]: any },
  scenario: UnitCommitmentScenario,
): [{ [key: string]: any }, ValidationError | null] => {
  // Parse value
  const [newValueFloat, err] = parseNumber(newValueStr);
  if (err) return [container, err];

  // Convert HH:MM to offset
  const hours = parseInt(time.split(":")[0]!, 10);
  const min = parseInt(time.split(":")[1]!, 10);
  const idx = (hours * 60 + min) / scenario.Parameters["Time step (min)"];

  // Build the new vector
  const newVec = [...container[field]];
  newVec[idx] = newValueFloat;
  return [
    {
      ...container,
      [field]: newVec,
    },
    null,
  ];
};

export const changeData = (
  field: string,
  newValueStr: string,
  container: { [key: string]: any },
  colSpecs: ColumnSpec[],
  scenario: UnitCommitmentScenario,
): [{ [key: string]: any }, ValidationError | null] => {
  const match = field.match(/^([^0-9]+)(\d+:\d+)?$/);
  const fieldName = match![1]!.trim();
  const fieldTime = match![2];
  for (const spec of colSpecs) {
    if (spec.title !== fieldName) continue;
    switch (spec.type) {
      case "string":
        return changeStringData(fieldName, newValueStr, container);
      case "busRef":
        return changeBusRefData(fieldName, newValueStr, container, scenario);
      case "number":
        return changeNumberData(fieldName, newValueStr, container);
      case "number[]":
        return changeNumberVecData(
          fieldName,
          fieldTime!,
          newValueStr,
          container,
          scenario,
        );
      default:
        throw Error(`Unknown type: ${spec.type}`);
    }
  }
  throw Error(`Unknown field: ${fieldName}`);
};
