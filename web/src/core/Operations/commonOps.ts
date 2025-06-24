/*
 * UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
 * Copyright (C) 2020-2025, UChicago Argonne, LLC. All rights reserved.
 * Released under the modified BSD license. See COPYING.md for more details.
 */

import { ValidationError } from "../Validation/validate";

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
