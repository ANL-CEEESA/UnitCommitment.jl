/*
 * UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
 * Copyright (C) 2020-2025, UChicago Argonne, LLC. All rights reserved.
 * Released under the modified BSD license. See COPYING.md for more details.
 */

import { Buses, UnitCommitmentScenario } from "../../../core/fixtures";
import Papa from "papaparse";
import { generateBusesColumns } from "./Buses";

export const parseBusesCsv = (
  scenario: UnitCommitmentScenario,
  csvData: string,
): UnitCommitmentScenario => {
  const results = Papa.parse(csvData, {
    header: true,
    skipEmptyLines: true,
    transformHeader: (header) => header.trim(),
    transform: (value) => value.trim(),
  });

  // Check for parsing errors
  if (results.errors.length > 0) {
    throw Error(`Invalid CSV: Parsing error: ${results.errors}`);
  }

  // Check CSV headers
  const expectedFields = generateBusesColumns(scenario).map(
    (col) => col.field,
  )!;
  const actualFields = results.meta.fields!;
  for (let i = 0; i < expectedFields.length; i++) {
    if (expectedFields[i] !== actualFields[i]) {
      throw Error(`Invalid CSV: Header mismatch at column ${i + 1}"`);
    }
  }

  // Parse each row
  const T = getNumTimesteps(scenario);
  const buses: Buses = {};
  for (let i = 0; i < results.data.length; i++) {
    const row = results.data[i] as { [key: string]: any };
    const busName = row["Name"] as string;
    const busLoad: number[] = Array(T);
    for (let j = 0; j < T; j++) {
      busLoad[j] = parseFloat(row[`Load ${j}`]);
    }
    buses[busName] = {
      "Load (MW)": busLoad,
    };
  }
  return {
    ...scenario,
    Buses: buses,
  };
};

function getNumTimesteps(scenario: UnitCommitmentScenario) {
  return (
    (scenario.Parameters["Time horizon (h)"] *
      scenario.Parameters["Time step (min)"]) /
    60
  );
}
