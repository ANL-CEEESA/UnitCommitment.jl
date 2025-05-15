/*
 * UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
 * Copyright (C) 2020-2025, UChicago Argonne, LLC. All rights reserved.
 * Released under the modified BSD license. See COPYING.md for more details.
 */

import {Buses, UnitCommitmentScenario} from "../../../core/data";

function generateUniqueBusName(scenario: UnitCommitmentScenario) {
    let newBusName = "b";
    let counter = 1;
    let name = `${newBusName}${counter}`;
    while (name in scenario.Buses) {
        counter++;
        name = `${newBusName}${counter}`;
    }
    return name;
}

function generateDefaultBusLoad(scenario: UnitCommitmentScenario) {
    const T = scenario.Parameters["Time horizon (h)"] * (60 / scenario.Parameters["Time step (min)"]);
    return new Array(T).fill(0);
}

export function createBus(scenario: UnitCommitmentScenario) {
    const load = generateDefaultBusLoad(scenario);
    let name = generateUniqueBusName(scenario);
    return {
        ...scenario,
        "Buses": {
            ...scenario.Buses,
            [name]: {
                "Load (MW)": load
            }
        }
    };
}

export function changeBusData(bus: string, field: string, newValue: string, scenario: UnitCommitmentScenario) {
    // Load (MW)
    const match = field.match(/Load (\d+)/);
    if(match) {
        const idx = parseInt(match[1]!, 10);
        const newLoad = [...scenario.Buses[bus]!["Load (MW)"]];
        newLoad[idx] = parseFloat(newValue);
        return {
            ...scenario,
            Buses: {
                ...scenario.Buses,
                [bus]: {
                    "Load (MW)": newLoad,
                }
            }
        };
    }

    throw Error(`Unknown field: ${field}`);
}

export function deleteBus(bus: string, scenario: UnitCommitmentScenario) {
    const { [bus]: _, ...newBuses} = scenario.Buses;
    return {
        ...scenario,
        Buses: newBuses
    };
}

export function renameBus(oldName: string, newName: string, scenario: UnitCommitmentScenario) {
    const newBuses: Buses = Object.keys(scenario.Buses).reduce((acc, val) => {
       if(val === oldName) {
           acc[newName] = scenario.Buses[val]!;
       } else {
           acc[val] = scenario.Buses[val]!;
       }
       return acc;
    }, {} as Buses);
    return {
        ...scenario,
        Buses: newBuses
    };
}