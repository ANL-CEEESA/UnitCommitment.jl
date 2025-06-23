import { UnitCommitmentScenario } from "./fixtures";

export const TEST_DATA_1: UnitCommitmentScenario = {
  Parameters: {
    Version: "0.4",
    "Power balance penalty ($/MW)": 1000.0,
    "Time horizon (h)": 5,
    "Time step (min)": 60,
  },
  Buses: {
    b1: { "Load (MW)": [35.79534, 34.38835, 33.45083, 32.89729, 33.25044] },
    b2: { "Load (MW)": [14.03739, 13.48563, 13.11797, 12.9009, 13.03939] },
    b3: { "Load (MW)": [27.3729, 26.29698, 25.58005, 25.15675, 25.4268] },
  },
};
export const TEST_DATA_2: UnitCommitmentScenario = {
  Parameters: {
    Version: "0.4",
    "Power balance penalty ($/MW)": 1000.0,
    "Time horizon (h)": 2,
    "Time step (min)": 30,
  },
  Buses: {
    b1: { "Load (MW)": [30, 30, 30, 30] },
    b2: { "Load (MW)": [10, 20, 30, 40] },
    b3: { "Load (MW)": [0, 30, 0, 40] },
  },
};

test("fixtures", () => {});
