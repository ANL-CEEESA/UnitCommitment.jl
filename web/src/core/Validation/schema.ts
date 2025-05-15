/*
 * UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
 * Copyright (C) 2020-2025, UChicago Argonne, LLC. All rights reserved.
 * Released under the modified BSD license. See COPYING.md for more details.
 */

export const schema = {
  $schema: "http://json-schema.org/draft-07/schema#",
  title: "Schema for Unit Commitment Input File",
  definitions: {
    Parameters: {
      type: "object",
      properties: {
        Version: {
          type: "string",
          const: "0.4",
          description: "Version of UnitCommitment.jl",
        },
        "Time horizon (min)": {
          type: "number",
          exclusiveMinimum: 0,
          description: "Length of the planning horizon in minutes",
        },
        "Time horizon (h)": {
          type: "number",
          exclusiveMinimum: 0,
          description: "Length of the planning horizon in hours",
        },
        "Time step (min)": {
          type: "number",
          default: 60,
          enum: [60, 30, 20, 15, 12, 10, 6, 5, 4, 3, 2, 1],
          description: "Must be a divisor of 60",
        },
        "Power balance penalty ($/MW)": {
          type: "number",
          default: 1000.0,
          minimum: 0,
          description: "Penalty for system-wide shortage or surplus",
        },
        "Scenario name": {
          type: "string",
          default: "s1",
          description: "Name of the scenario",
        },
        "Scenario weight": {
          type: "number",
          default: 1.0,
          exclusiveMinimum: 0,
          description: "Weight of the scenario",
        },
      },
      required: ["Time step (min)", "Power balance penalty ($/MW)"],
      oneOf: [
        { required: ["Time horizon (min)"] },
        { required: ["Time horizon (h)"] },
      ],
      not: {
        required: ["Time horizon (min)", "Time horizon (h)"],
      },
    },
    Bus: {
      type: "object",
      additionalProperties: {
        type: "object",
        properties: {
          "Load (MW)": {
            oneOf: [
              { type: "null" },
              { type: "number" },
              {
                type: "array",
                items: {
                  oneOf: [{ type: "number" }, { type: "null" }],
                },
              },
            ],
          },
        },
      },
    },
    TransmissionLines: {
      type: "object",
      additionalProperties: {
        type: "object",
        properties: {
          "Source bus": {
            type: "string",
            minLength: 1,
          },
          "Target bus": {
            type: "string",
            minLength: 1,
            not: {
              const: { $data: "1/Source bus" },
            },
          },
          "Susceptance (S)": {
            type: "number",
            minimum: 0,
          },
          "Normal flow limit (MW)": {
            type: "number",
            minimum: 0,
          },
          "Emergency flow limit (MW)": {
            type: "number",
            minimum: 0,
          },
          "Flow limit penalty ($/MW)": {
            type: "number",
            minimum: 0,
            default: 5000.0,
          },
        },
        required: ["Source bus", "Target bus", "Susceptance (S)"],
      },
    },
    StorageUnits: {
      type: "object",
      additionalProperties: {
        type: "object",
        properties: {
          Bus: {
            type: "string",
            minLength: 1,
          },
          "Minimum level (MWh)": {
            type: "number",
          },
          "Maximum level (MWh)": {
            type: "number",
            minimum: 0,
          },
          "Allow simultaneous charging and discharging": {
            type: "boolean",
            default: true,
          },
          "Charge cost ($/MW)": {
            type: "number",
            minimum: 0,
          },
          "Discharge cost ($/MW)": {
            type: "number",
            minimum: 0,
          },
          "Charge efficiency": {
            type: "number",
            minimum: 0,
            maximum: 1,
          },
          "Discharge efficiency": {
            type: "number",
            minimum: 0,
            maximum: 1,
          },
          "Loss factor": {
            type: "number",
            minimum: 0,
          },
          "Minimum charge rate (MW)": {
            type: "number",
            minimum: 0,
          },
          "Maximum charge rate (MW)": {
            type: "number",
            minimum: 0,
          },
          "Minimum discharge rate (MW)": {
            type: "number",
            minimum: 0,
          },
          "Maximum discharge rate (MW)": {
            type: "number",
            minimum: 0,
          },
          "Initial level (MWh)": {
            type: "number",
            minimum: 0,
          },
          "Last period minimum level (MWh)": {
            type: "number",
            minimum: 0,
          },
          "Last period maximum level (MWh)": {
            type: "number",
            minimum: 0,
          },
        },
        required: ["Bus"],
      },
    },
    Generators: {
      type: "object",
      additionalProperties: {
        type: "object",
        if: {
          properties: {
            Type: { const: "Thermal" },
          },
        },
        then: {
          properties: {
            Bus: {
              type: "string",
              minLength: 1,
            },
            Type: {
              type: "string",
              const: "Thermal",
            },
            "Production cost curve (MW)": {
              type: "array",
              items: {
                type: "number",
                minimum: 0,
              },
              minItems: 1,
            },
            "Production cost curve ($)": {
              type: "array",
              items: {
                type: "number",
                minimum: 0,
              },
              minItems: 1,
            },
            "Startup costs ($)": {
              type: "array",
              items: {
                type: "number",
                minimum: 0,
              },
              default: [0.0],
            },
            "Startup delays (h)": {
              type: "array",
              items: {
                type: "integer",
                minimum: 1,
              },
              default: [1],
            },
            "Minimum uptime (h)": {
              type: "integer",
              default: 1,
              minimum: 0,
            },
            "Minimum downtime (h)": {
              type: "integer",
              default: 1,
              minimum: 0,
            },
            "Ramp up limit (MW)": {
              type: "number",
              minimum: 0,
            },
            "Ramp down limit (MW)": {
              type: "number",
              minimum: 0,
            },
            "Startup limit (MW)": {
              type: "number",
              minimum: 0,
            },
            "Shutdown limit (MW)": {
              type: "number",
              minimum: 0,
            },
            "Initial status (h)": {
              type: "integer",
              default: 1,
              not: { const: 0 },
            },
            "Initial power (MW)": {
              type: "number",
              minimum: 0,
            },
            "Must run?": {
              type: "boolean",
              default: false,
            },
          },
          required: [
            "Bus",
            "Type",
            "Production cost curve (MW)",
            "Production cost curve ($)",
            "Initial status (h)",
            "Initial power (MW)",
          ],
        },
        else: {
          properties: {
            Type: { const: "Profiled" },
            Bus: {
              type: "string",
              minLength: 1,
            },
            "Maximum power (MW)": {
              oneOf: [
                {
                  type: "number",
                },
                {
                  type: "array",
                  items: {
                    type: "number",
                  },
                },
              ],
            },
            "Cost ($/MW)": {
              type: "number",
              minimum: 0,
            },
          },
          required: ["Type", "Bus", "Maximum power (MW)", "Cost ($/MW)"],
        },
      },
    },
    Contingencies: {
      type: "object",
      additionalProperties: {
        type: "object",
        properties: {
          "Affected lines": {
            type: "array",
            items: {
              type: "string",
            },
            maxItems: 1,
            minItems: 1,
          },
        },
        required: ["Affected lines"],
      },
    },
  },
  type: "object",
  properties: {
    Parameters: {
      $ref: "#/definitions/Parameters",
    },
    Buses: {
      $ref: "#/definitions/Bus",
    },
    "Transmission lines": {
      $ref: "#/definitions/TransmissionLines",
    },
    "Storage units": {
      $ref: "#/definitions/StorageUnits",
    },
    Generators: {
      $ref: "#/definitions/Generators",
    },
    Contingencies: {
      $ref: "#/definitions/Contingencies",
    },
  },
  required: ["Parameters"],
};
