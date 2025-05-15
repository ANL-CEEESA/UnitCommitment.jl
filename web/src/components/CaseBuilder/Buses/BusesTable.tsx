/*
 * UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
 * Copyright (C) 2020-2025, UChicago Argonne, LLC. All rights reserved.
 * Released under the modified BSD license. See COPYING.md for more details.
 */

import Papa from 'papaparse';
import {Buses, UnitCommitmentScenario} from "../../../core/data";
import {useEffect, useRef} from "react";
import {CellComponent, ColumnDefinition, TabulatorFull as Tabulator} from "tabulator-tables";

const generateBusesTableData = (scenario: UnitCommitmentScenario) => {
    const tableData: { [name: string]: any }[] = [];
    for (const [busName, busData] of Object.entries(scenario.Buses)) {
        const entry: { [key: string]: any } = {};
        entry["Name"] = busName;
        for (const [i, mw] of Object.entries(busData["Load (MW)"])) {
            entry[`Load ${i}`] = mw;
        }
        tableData.push(entry);
    }
    return tableData;
};

const generateBusesTableColumns = (scenario: UnitCommitmentScenario): [ColumnDefinition] => {
    const timeHorizonHours = scenario["Parameters"]["Time horizon (h)"];
    const timeStepMin = scenario["Parameters"]["Time step (min)"];
    const columnsCommonAttrs: ColumnDefinition = {
        title: "",
        editor: "input",
        editorParams: {
            selectContents: true,
        },
        headerHozAlign: "right",
        cssClass: "custom-cell-style",
        headerWordWrap: true,
        formatter: "plaintext",
        headerSort: false,
        resizable: false,
    };
    const columns: [ColumnDefinition] = [
        {
            ...columnsCommonAttrs,
            title: "Name",
            field: "Name",
            width: 150,
        },
    ];
    for (let m = 0, offset = 0; m < timeHorizonHours * 60; m += timeStepMin, offset += 1) {
        const hours = Math.floor(m / 60);
        const mins = m % 60;
        const formattedTime = `${String(hours).padStart(2, '0')}:${String(mins).padStart(2, '0')}`;
        columns.push({
            ...columnsCommonAttrs,
            title: `Load (MW)<div class="subtitle">${formattedTime}</div>`,
            field: `Load ${offset}`,
            width: 100,
        });
    }
    return columns;
};

export const generateBusesCsv = (scenario: UnitCommitmentScenario) => {
    const columns = generateBusesTableColumns(scenario);
    const csvHeader = columns.map(row => row.field).join(",");
    const csvBody = Object.entries(scenario.Buses).map(([busName, busData]) => {
        const csvLoad = busData["Load (MW)"].join(",");
        return `${busName},${csvLoad}`;
    }).join("\n");
    return `${csvHeader}\n${csvBody}`;
};

function getNumTimesteps(scenario: UnitCommitmentScenario) {
    return scenario.Parameters["Time horizon (h)"] * scenario.Parameters["Time step (min)"] / 60;
}

export const parseBusesCsv = (scenario: UnitCommitmentScenario, csvData: string): UnitCommitmentScenario => {
    const results = Papa.parse(csvData, {
        header: true,
        skipEmptyLines: true,
        transformHeader: (header) => header.trim(),
        transform: (value) => value.trim()
    });

    // Check for parsing errors
    if (results.errors.length > 0) {
        throw Error(`Invalid CSV: Parsing error: ${results.errors}`);
    }

    // Check CSV headers
    const expectedFields = generateBusesTableColumns(scenario).map(col => col.field)!;
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
            "Load (MW)": busLoad
        };
    }
    return {
        ...scenario,
        Buses: buses,
    };
};

interface BusesTableProps {
    scenario: UnitCommitmentScenario
    onBusDataChanged: (bus: string, field: string, newValue: string) => void,
    onBusDeleted: (bus: string) => void,
    onBusRenamed: (oldName: string, newName: string) => void,
}

function BusesTable(props: BusesTableProps) {
    const tableContainerRef = useRef<HTMLDivElement | null>(null);

    useEffect(() => {
        const onCellEdited = (cell: CellComponent) => {
            let newValue = cell.getValue();
            let oldValue = cell.getOldValue();
            if (newValue === oldValue) return;

            if (cell.getField() === "Name") {
                if (newValue === "") {
                    props.onBusDeleted(oldValue);
                    cell.getRow().delete();
                } else {
                    props.onBusRenamed(
                        oldValue,
                        newValue,
                    );
                }
            } else {
                const row = cell.getRow().getData();
                const bus = row["Name"];
                props.onBusDataChanged(
                    bus, cell.getField(), newValue
                );
            }
        };
        
        if (tableContainerRef.current === null) return;
        const table = new Tabulator(tableContainerRef.current, {
            layout: "fitColumns",
            data: generateBusesTableData(props.scenario),
            columns: generateBusesTableColumns(props.scenario),
            maxHeight: "500px",
        });
        table.on("cellEdited", (cell) => {
            onCellEdited(cell);
        });
        table.on("cellEditing", (cell) => {
        });
        // table.on("scrollHorizontal", (left, leftDir) => {
        //   console.log(left, leftDir);
        // });
        table.rowManager.scrollHorizontal(100, false);
        // table.columnManager.scrollHorizontal(100, false);
    }, [props, props.scenario]);

    return <div className="tableContainer" ref={tableContainerRef}/>;
}

export default BusesTable;

