/*
 * UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
 * Copyright (C) 2020-2025, UChicago Argonne, LLC. All rights reserved.
 * Released under the modified BSD license. See COPYING.md for more details.
 */

import { Buses, UnitCommitmentScenario } from "../../../core/data";
import { ValidationError } from "../../../core/Validation/validate";

export const changeTimeHorizon = (
  scenario: UnitCommitmentScenario,
  newTimeHorizonStr: string,
): [UnitCommitmentScenario, ValidationError | null] => {
  // Parse string
  const newTimeHorizon = parseInt(newTimeHorizonStr);
  if (isNaN(newTimeHorizon) || newTimeHorizon <= 0) {
    return [scenario, { message: `Invalid value: ${newTimeHorizonStr}` }];
  }
  const newScenario = JSON.parse(
    JSON.stringify(scenario),
  ) as UnitCommitmentScenario;
  newScenario.Parameters["Time horizon (h)"] = newTimeHorizon;
  const newT = (newTimeHorizon * 60) / scenario.Parameters["Time step (min)"];
  const oldT =
    (scenario.Parameters["Time horizon (h)"] * 60) /
    scenario.Parameters["Time step (min)"];
  if (newT < oldT) {
    Object.values(newScenario.Buses).forEach((bus) => {
      bus["Load (MW)"] = bus["Load (MW)"].slice(0, newT);
    });
  } else {
    const padding = Array(newT - oldT).fill(0);
    Object.values(newScenario.Buses).forEach((bus) => {
      bus["Load (MW)"] = bus["Load (MW)"].concat(padding);
    });
  }
  return [newScenario, null];
};

export const evaluatePwlFunction = (
  data_x: number[],
  data_y: number[],
  x: number,
) => {
  if (x < data_x[0]! || x > data_x[data_x.length - 1]!) {
    throw Error("PWL interpolation: Out of bounds");
  }

  if (x === data_x[0]) return data_y[0];

  // Binary search to find the interval containing x
  let low = 0;
  let high = data_x.length - 1;
  while (low < high) {
    let mid = Math.floor((low + high) / 2);
    if (data_x[mid]! < x) low = mid + 1;
    else high = mid;
  }

  // Linear interpolation within the found interval
  const x1 = data_x[low - 1]!;
  const y1 = data_y[low - 1]!;
  const x2 = data_x[low]!;
  const y2 = data_y[low]!;

  return y1 + ((x - x1) * (y2 - y1)) / (x2 - x1);
};

export const changeTimeStep = (
  scenario: UnitCommitmentScenario,
  newTimeStepStr: string,
): [UnitCommitmentScenario, ValidationError | null] => {
  // Parse string and perform validation
  const newTimeStep = parseFloat(newTimeStepStr);
  if (isNaN(newTimeStep) || newTimeStep < 1 || newTimeStep > 60) {
    return [scenario, { message: `Invalid value: ${newTimeStepStr}` }];
  }
  if (60 % newTimeStep !== 0) {
    return [
      scenario,
      { message: `Time step must be a divisor of 60: ${newTimeStepStr}` },
    ];
  }

  // Build data_x
  let timeHorizon = scenario.Parameters["Time horizon (h)"];
  const oldTimeStep = scenario.Parameters["Time step (min)"];
  const oldT = (timeHorizon * 60) / oldTimeStep;
  const newT = (timeHorizon * 60) / newTimeStep;
  const data_x = Array(oldT + 1).fill(0);
  for (let i = 0; i <= oldT; i++) data_x[i] = i * oldTimeStep;

  const newBuses: Buses = {};
  for (const busName in scenario.Buses) {
    // Build data_y
    const busLoad = scenario.Buses[busName]!["Load (MW)"];
    const data_y = Array(oldT + 1).fill(0);
    for (let i = 0; i < oldT; i++) data_y[i] = busLoad[i];
    data_y[oldT] = data_y[0];

    // Run interpolation
    const newBusLoad = Array(newT).fill(0);
    for (let i = 0; i < newT; i++) {
      newBusLoad[i] = evaluatePwlFunction(data_x, data_y, newTimeStep * i);
    }
    newBuses[busName] = {
      ...scenario.Buses[busName],
      "Load (MW)": newBusLoad,
    };
  }

  return [
    {
      ...scenario,
      Parameters: {
        ...scenario.Parameters,
        "Time step (min)": newTimeStep,
      },
      Buses: newBuses,
    },
    null,
  ];
};
