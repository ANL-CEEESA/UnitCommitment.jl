/*
 * UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
 * Copyright (C) 2020-2025, UChicago Argonne, LLC. All rights reserved.
 * Released under the modified BSD license. See COPYING.md for more details.
 */

import { Buses, UnitCommitmentScenario } from "../fixtures";
import { ValidationError } from "../Validation/validate";
import { generateTimeslots } from "../../components/Common/Forms/DataTable";

export const generateUniqueName = (container: any, prefix: string): string => {
  let counter = 1;
  let name = `${prefix}${counter}`;
  while (name in container) {
    counter++;
    name = `${prefix}${counter}`;
  }
  return name;
};

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
  // Load (MW)
  const match = field.match(/Load \(MW\) (\d+):(\d+)/);
  if (match) {
    const newValueFloat = parseFloat(newValueStr);
    if (isNaN(newValueFloat)) {
      return [scenario, { message: `Invalid value: ${newValueStr}` }];
    }

    // Convert HH:MM to offset
    const hours = parseInt(match[1]!, 10);
    const min = parseInt(match[2]!, 10);
    const idx = (hours * 60 + min) / scenario.Parameters["Time step (min)"];

    const newLoad = [...scenario.Buses[bus]!["Load (MW)"]];
    newLoad[idx] = newValueFloat;
    return [
      {
        ...scenario,
        Buses: {
          ...scenario.Buses,
          [bus]: {
            "Load (MW)": newLoad,
          },
        },
      },
      null,
    ];
  }

  throw Error(`Unknown field: ${field}`);
};

export const deleteBus = (bus: string, scenario: UnitCommitmentScenario) => {
  const { [bus]: _, ...newBuses } = scenario.Buses;
  return {
    ...scenario,
    Buses: newBuses,
  };
};

export const renameBus = (
  oldName: string,
  newName: string,
  scenario: UnitCommitmentScenario,
): [UnitCommitmentScenario, ValidationError | null] => {
  if (newName in scenario.Buses) {
    return [scenario, { message: `Bus ${newName} already exists` }];
  }
  const newBuses: Buses = Object.keys(scenario.Buses).reduce((acc, val) => {
    if (val === oldName) {
      acc[newName] = scenario.Buses[val]!;
    } else {
      acc[val] = scenario.Buses[val]!;
    }
    return acc;
  }, {} as Buses);
  return [
    {
      ...scenario,
      Buses: newBuses,
    },
    null,
  ];
};
