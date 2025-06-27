/*
 * UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
 * Copyright (C) 2020-2025, UChicago Argonne, LLC. All rights reserved.
 * Released under the modified BSD license. See COPYING.md for more details.
 */

import { Buses } from "./fixtures";

export interface Generators {
  [name: string]: ProfiledUnit | ThermalUnit;
}

export interface ProfiledUnit {
  Bus: string;
  Type: "Profiled";
  "Minimum power (MW)": number[];
  "Maximum power (MW)": number[];
  "Cost ($/MW)": number;
}

export interface ThermalUnit {
  Bus: string;
  Type: "Thermal";
  "Production cost curve (MW)": number[];
  "Production cost curve ($)": number[];
  "Startup costs ($)": number[];
  "Startup delays (h)": number[];
  "Ramp up limit (MW)": number | "";
  "Ramp down limit (MW)": number | "";
  "Startup limit (MW)": number | "";
  "Shutdown limit (MW)": number | "";
  "Minimum downtime (h)": number;
  "Minimum uptime (h)": number;
  "Initial status (h)": number;
  "Initial power (MW)": number;
  "Must run?": boolean;
}

export interface TransmissionLine {
  "Source bus": string;
  "Target bus": string;
  "Susceptance (S)": number;
  "Normal flow limit (MW)": number;
  "Emergency flow limit (MW)": number;
  "Flow limit penalty ($/MW)": number;
}

export interface UnitCommitmentScenario {
  Parameters: {
    Version: string;
    "Power balance penalty ($/MW)": number;
    "Time horizon (h)": number;
    "Time step (min)": number;
  };
  Buses: Buses;
  Generators: Generators;
  "Transmission lines": {
    [name: string]: TransmissionLine;
  };
}

const getTypedGenerators = <T extends any>(
  scenario: UnitCommitmentScenario,
  type: string,
): {
  [key: string]: T;
} => {
  const selected: { [key: string]: T } = {};
  for (const [name, gen] of Object.entries(scenario.Generators)) {
    if (gen["Type"] === type) selected[name] = gen as T;
  }
  return selected;
};
export const getProfiledGenerators = (
  scenario: UnitCommitmentScenario,
): { [key: string]: ProfiledUnit } =>
  getTypedGenerators<ProfiledUnit>(scenario, "Profiled");
export const getThermalGenerators = (
  scenario: UnitCommitmentScenario,
): { [key: string]: ThermalUnit } =>
  getTypedGenerators<ThermalUnit>(scenario, "Thermal");
