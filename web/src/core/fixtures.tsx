/*
 * UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
 * Copyright (C) 2020-2025, UChicago Argonne, LLC. All rights reserved.
 * Released under the modified BSD license. See COPYING.md for more details.
 */

export interface Buses {
  [busName: string]: { "Load (MW)": number[] };
}

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
  "Ramp up limit (MW)": number;
  "Ramp down limit (MW)": number;
  "Startup limit (MW)": number;
  "Shutdown limit (MW)": number;
  "Minimum downtime (h)": number;
  "Minimum uptime (h)": number;
  "Initial status (h)": number;
  "Initial power (MW)": number;
  "Must run?": boolean;
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

export const BLANK_SCENARIO: UnitCommitmentScenario = {
  Parameters: {
    Version: "0.4",
    "Power balance penalty ($/MW)": 1000.0,
    "Time horizon (h)": 24,
    "Time step (min)": 60,
  },
  Buses: {},
  Generators: {},
};

export const TEST_SCENARIO: UnitCommitmentScenario = {
  Parameters: {
    Version: "0.4",
    "Power balance penalty ($/MW)": 1000.0,
    "Time horizon (h)": 36,
    "Time step (min)": 60,
  },
  Buses: {
    b1: {
      "Load (MW)": [
        35.79534, 34.38835, 33.45083, 32.89729, 33.25044, 33.93851, 35.8654,
        37.27098, 38.08378, 38.99327, 38.65134, 38.83212, 37.60031, 37.27939,
        37.11823, 37.73063, 40.951, 44.77115, 43.67527, 44.40959, 44.33812,
        42.29071, 40.07654, 37.42093, 35.61175, 34.28185, 32.74174, 33.17336,
        33.5181, 35.63558, 38.12722, 39.61689, 40.80105, 42.55277, 42.76017,
        42.12535,
      ],
    },
    b2: {
      "Load (MW)": [
        14.03739, 13.48563, 13.11797, 12.9009, 13.03939, 13.30922, 14.06486,
        14.61607, 14.93482, 15.29148, 15.15739, 15.22828, 14.74522, 14.61937,
        14.55617, 14.79633, 16.05921, 17.55731, 17.12756, 17.41553, 17.3875,
        16.58459, 15.71629, 14.67487, 13.96539, 13.44386, 12.8399, 13.00916,
        13.14435, 13.97474, 14.95185, 15.53603, 16.00041, 16.68736, 16.76869,
        16.51974,
      ],
    },
    b3: {
      "Load (MW)": [
        27.3729, 26.29698, 25.58005, 25.15675, 25.4268, 25.95298, 27.42649,
        28.50134, 29.12289, 29.81839, 29.55691, 29.69515, 28.75318, 28.50777,
        28.38453, 28.85284, 31.31547, 34.23676, 33.39874, 33.96028, 33.90562,
        32.33996, 30.64676, 28.61601, 27.23252, 26.21553, 25.0378, 25.36786,
        25.63149, 27.25074, 29.15611, 30.29527, 31.2008, 32.54035, 32.69895,
        32.2135,
      ],
    },
    b4: {
      "Load (MW)": [
        27.5, 26.29698, 25.58005, 25.15675, 25.4268, 25.95298, 27.42649,
        28.50134, 29.12289, 29.81839, 29.55691, 29.69515, 28.75318, 28.50777,
        28.38453, 28.85284, 31.31547, 34.23676, 33.39874, 33.96028, 33.90562,
        32.33996, 30.64676, 28.61601, 27.23252, 26.21553, 25.0378, 25.36786,
        25.63149, 27.25074, 29.15611, 30.29527, 31.2008, 32.54035, 32.69895,
        32.2135,
      ],
    },
  },
  Generators: {
    pu1: {
      Bus: "b1",
      Type: "Profiled",
      "Minimum power (MW)": [
        52.05076909, 14.57829614, 75.43577222, 67.33346472, 75.36556352,
        21.57017795, 38.57431892, 46.71083643, 97.87434963, 95.12592361,
        82.00040834, 25.97388027, 14.87169082, 8.68106053, 43.67452089,
        18.95280541, 85.59390327, 59.62398136, 81.30530633, 83.61173632,
        10.07929569, 87.96736565, 84.65719304, 30.57367207, 27.39181212,
        78.27367461, 6.81518238, 68.40723311, 19.616812, 60.20940984,
        58.57199889, 89.50587265, 65.26434981, 78.57656542, 52.20154156,
        42.79584818,
      ],
      "Maximum power (MW)": [
        260.25384545, 72.89148068, 377.17886108, 336.66732361, 376.82781758,
        107.85088974, 192.8715946, 233.55418217, 489.37174815, 475.62961804,
        410.00204171, 129.86940137, 74.35845412, 43.40530267, 218.37260447,
        94.76402706, 427.96951634, 298.11990681, 406.52653167, 418.05868161,
        50.39647843, 439.83682824, 423.28596522, 152.86836035, 136.95906058,
        391.36837307, 34.0759119, 342.03616557, 98.08406001, 301.04704921,
        292.85999447, 447.52936326, 326.32174903, 392.88282708, 261.0077078,
        213.9792409,
      ],
      "Cost ($/MW)": 50.0,
    },
    gen1: {
      Bus: "b1",
      Type: "Thermal",
      "Production cost curve (MW)": [100.0, 110.0, 130.0, 135.0],
      "Production cost curve ($)": [1400.0, 1600.0, 2200.0, 2400.0],
      "Startup costs ($)": [300.0, 400.0],
      "Startup delays (h)": [1, 4],
      "Ramp up limit (MW)": 232.68,
      "Ramp down limit (MW)": 232.68,
      "Startup limit (MW)": 232.68,
      "Shutdown limit (MW)": 232.68,
      "Minimum downtime (h)": 4,
      "Minimum uptime (h)": 4,
      "Initial status (h)": 12,
      "Initial power (MW)": 115,
      "Must run?": false,
    },
  },
};
