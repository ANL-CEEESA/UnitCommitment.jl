/*
 * UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
 * Copyright (C) 2020-2025, UChicago Argonne, LLC. All rights reserved.
 * Released under the modified BSD license. See COPYING.md for more details.
 */

import { useEffect, useRef, useState } from "react";
import {
  CellComponent,
  ColumnDefinition,
  TabulatorFull as Tabulator,
} from "tabulator-tables";
import { ValidationError } from "../../../core/Data/validate";
import Papa from "papaparse";
import { parseBool, parseNumber } from "../../../core/Operations/commonOps";
import { UnitCommitmentScenario } from "../../../core/Data/types";

export interface ColumnSpec {
  title: string;
  type: "string" | "number" | "number[N]" | "number[T]" | "busRef" | "boolean";
  length?: number;
  width: number;
}

export const generateTableColumns = (
  scenario: UnitCommitmentScenario,
  colSpecs: ColumnSpec[],
) => {
  const timeSlots = generateTimeslots(scenario);
  const columns: ColumnDefinition[] = [];
  colSpecs.forEach((spec) => {
    const subColumns: ColumnDefinition[] = [];
    switch (spec.type) {
      case "string":
      case "busRef":
        columns.push({
          ...columnsCommonAttrs,
          title: spec.title,
          field: spec.title,
          minWidth: spec.width,
        });
        break;
      case "boolean":
        columns.push({
          ...columnsCommonAttrs,
          title: spec.title,
          field: spec.title,
          minWidth: spec.width,
          editor: "list",
          editorParams: {
            values: [true, false],
          },
        });
        break;
      case "number":
        columns.push({
          ...columnsCommonAttrs,
          title: spec.title,
          field: spec.title,
          minWidth: spec.width,
          formatter: floatFormatter,
        });
        break;
      case "number[T]":
        timeSlots.forEach((t) => {
          subColumns.push({
            ...columnsCommonAttrs,
            title: `${t}`,
            field: `${spec.title} ${t}`,
            minWidth: spec.width,
            formatter: floatFormatter,
          });
        });
        columns.push({
          title: spec.title,
          columns: subColumns,
        });
        break;
      case "number[N]":
        for (let i = 1; i <= spec.length!; i++) {
          subColumns.push({
            ...columnsCommonAttrs,
            title: `${i}`,
            field: `${spec.title} ${i}`,
            minWidth: spec.width,
            formatter: floatFormatter,
          });
        }
        columns.push({
          title: spec.title,
          columns: subColumns,
        });
        break;
      default:
        throw Error(`Unknown type: ${spec.type}`);
    }
  });
  return columns;
};

export const generateTableData = (
  container: any,
  colSpecs: ColumnSpec[],
  scenario: UnitCommitmentScenario,
): any[] => {
  const data: any[] = [];
  const timeslots = generateTimeslots(scenario);
  for (const [entryName, entryData] of Object.entries(container) as [
    string,
    any,
  ]) {
    const entry: any = {};
    for (const spec of colSpecs) {
      if (spec.title === "Name") {
        entry["Name"] = entryName;
        continue;
      }
      switch (spec.type) {
        case "string":
        case "number":
        case "boolean":
        case "busRef":
          entry[spec.title] = entryData[spec.title];
          break;
        case "number[T]":
          for (let i = 0; i < timeslots.length; i++) {
            entry[`${spec.title} ${timeslots[i]}`] = entryData[spec.title][i];
          }
          break;
        case "number[N]":
          for (let i = 0; i < spec.length!; i++) {
            let v = entryData[spec.title][i];
            if (v === undefined || v === null) v = "";
            entry[`${spec.title} ${i + 1}`] = v;
          }
          break;
        default:
          throw Error(`Unknown type: ${spec.type}`);
      }
    }
    data.push(entry);
  }
  return data;
};

export const generateCsv = (data: any[], columns: ColumnDefinition[]) => {
  const header: string[] = [];
  const body: string[][] = data.map(() => []);
  columns.forEach((column) => {
    if (column.columns) {
      column.columns.forEach((subcolumn) => {
        header.push(subcolumn.field!);
        for (let i = 0; i < data.length; i++) {
          body[i]!.push(data[i]![subcolumn["field"]!]);
        }
      });
    } else {
      header.push(column.field!);
      for (let i = 0; i < data.length; i++) {
        body[i]!.push(data[i]![column["field"]!]);
      }
    }
  });
  const csvHeader = header.join(",");
  const csvBody = body.map((row) => row.join(",")).join("\n");
  return `${csvHeader}\n${csvBody}`;
};

export const parseCsv = (
  csvContents: string,
  colSpecs: ColumnSpec[],
  scenario: UnitCommitmentScenario,
): [any, ValidationError | null] => {
  // Parse contents
  const csv = Papa.parse(csvContents, {
    header: true,
    skipEmptyLines: true,
    transformHeader: (header) => header.trim(),
    transform: (value) => value.trim(),
  });

  // Check for parsing errors
  if (csv.errors.length > 0) {
    console.error(csv.errors);
    return [null, { message: "Could not parse CSV file" }];
  }

  // Check CSV headers
  const columns = generateTableColumns(scenario, colSpecs);
  const expectedHeader: string[] = [];
  columns.forEach((column) => {
    if (column.columns) {
      column.columns.forEach((subcolumn) => {
        expectedHeader.push(subcolumn.field!);
      });
    } else {
      expectedHeader.push(column.field!);
    }
  });
  const actualHeader = csv.meta.fields!;
  for (let i = 0; i < expectedHeader.length; i++) {
    if (expectedHeader[i] !== actualHeader[i]) {
      return [
        null,
        {
          message: `Invalid CSV: Header mismatch at column ${i + 1}. 
          Expected "${expectedHeader[i]}", found "${actualHeader[i]}"`,
        },
      ];
    }
  }

  // Parse each row
  const timeslots = generateTimeslots(scenario);
  const data: { [key: string]: any } = {};
  for (let i = 0; i < csv.data.length; i++) {
    const row = csv.data[i] as { [key: string]: any };
    const rowRef = ` (row ${i + 1})`;
    const name = row["Name"] as string;
    if (name in data) {
      return [null, { message: `Name "${name}" is duplicated` + rowRef }];
    }
    data[name] = {};

    for (const spec of colSpecs) {
      if (spec.title === "Name") continue;
      switch (spec.type) {
        case "string":
          data[name][spec.title] = row[spec.title];
          break;
        case "number": {
          const [val, err] = parseNumber(row[spec.title]);
          if (err) return [null, { message: err.message + rowRef }];
          data[name][spec.title] = val;
          break;
        }
        case "busRef":
          const busName = row[spec.title];
          if (!(busName in scenario.Buses)) {
            return [
              null,
              { message: `Bus "${busName}" does not exist` + rowRef },
            ];
          }
          data[name][spec.title] = row[spec.title];
          break;
        case "number[T]": {
          data[name][spec.title] = Array(timeslots.length);
          for (let i = 0; i < timeslots.length; i++) {
            const [vf, err] = parseNumber(row[`${spec.title} ${timeslots[i]}`]);
            if (err) return [data, { message: err.message + rowRef }];
            data[name][spec.title][i] = vf;
          }
          break;
        }
        case "number[N]": {
          data[name][spec.title] = Array(spec.length).fill(0);
          for (let i = 0; i < spec.length!; i++) {
            let v = row[`${spec.title} ${i + 1}`];
            if (v.trim() === "") {
              data[name][spec.title].splice(i, spec.length! - i);
              break;
            } else {
              const [vf, err] = parseNumber(row[`${spec.title} ${i + 1}`]);
              if (err) return [data, { message: err.message + rowRef }];
              data[name][spec.title][i] = vf;
            }
          }
          break;
        }
        case "boolean": {
          const [val, err] = parseBool(row[spec.title]);
          if (err) return [data, { message: err.message + rowRef }];
          data[name][spec.title] = val;
          break;
        }
        default:
          throw Error(`Unknown type: ${spec.type}`);
      }
    }
  }

  return [data, null];
};

export const floatFormatter = (cell: CellComponent) => {
  const v = cell.getValue();
  if (v === "") {
    return "&mdash;";
  } else {
    return parseFloat(cell.getValue()).toLocaleString("en-US", {
      minimumFractionDigits: 1,
      maximumFractionDigits: 1,
    });
  }
};

export const generateTimeslots = (scenario: UnitCommitmentScenario) => {
  const timeHorizonHours = scenario["Parameters"]["Time horizon (h)"];
  const timeStepMin = scenario["Parameters"]["Time step (min)"];
  const timeslots: string[] = [];
  for (
    let m = 0, offset = 0;
    m < timeHorizonHours * 60;
    m += timeStepMin, offset += 1
  ) {
    const hours = Math.floor(m / 60);
    const mins = m % 60;
    const formattedTime = `${String(hours).padStart(2, "0")}:${String(mins).padStart(2, "0")}`;
    timeslots.push(formattedTime);
  }
  return timeslots;
};

export const columnsCommonAttrs: ColumnDefinition = {
  headerHozAlign: "left",
  hozAlign: "left",
  title: "",
  editor: "input",
  editorParams: {
    selectContents: true,
  },
  headerWordWrap: true,
  formatter: "plaintext",
  headerSort: false,
  resizable: false,
};

interface DataTableProps {
  onRowDeleted: (rowName: string) => ValidationError | null;
  onRowRenamed: (
    oldRowName: string,
    newRowName: string,
  ) => ValidationError | null;
  onDataChanged: (
    rowName: string,
    key: string,
    newValue: string,
  ) => ValidationError | null;
  generateData: () => [any[], ColumnDefinition[]];
}

function computeTableHeight(data: any[]): string {
  const numRows = data.length;
  const height = 70 + Math.min(numRows, 15) * 28;
  return `${height}px`;
}

const DataTable = (props: DataTableProps) => {
  const tableContainerRef = useRef<HTMLDivElement | null>(null);
  const tableRef = useRef<Tabulator | null>(null);
  const [isTableBuilt, setTableBuilt] = useState<Boolean>(false);

  useEffect(() => {
    const onCellEdited = (cell: CellComponent) => {
      let newValue = `${cell.getValue()}`;
      let oldValue = `${cell.getOldValue()}`;
      if (newValue === oldValue) return;
      if (cell.getField() === "Name") {
        if (newValue === "") {
          const err = props.onRowDeleted(oldValue);
          if (err) {
            cell.restoreOldValue();
          } else {
            cell
              .getRow()
              .delete()
              .then((r) => {});
          }
        } else {
          const err = props.onRowRenamed(oldValue, newValue);
          if (err) {
            cell.restoreOldValue();
          }
        }
      } else {
        const row = cell.getRow().getData();
        const bus = row["Name"];
        const err = props.onDataChanged(bus, cell.getField(), newValue);
        if (err) {
          cell.restoreOldValue();
        }
      }
    };
    if (tableContainerRef.current === null) return;
    const [data, columns] = props.generateData();
    const height = computeTableHeight(data);

    if (tableRef.current === null) {
      tableRef.current = new Tabulator(tableContainerRef.current, {
        layout: "fitColumns",
        data: data,
        columns: columns,
        height: height,
      });
      tableRef.current.on("tableBuilt", () => {
        setTableBuilt(true);
      });
    }
    if (isTableBuilt) {
      const newHeight = height;
      const newColumns = columns;
      const newData = data;
      const oldRows = tableRef.current.getRows();

      // Update data
      tableRef.current.replaceData(newData).then(() => {});

      // Update columns
      if (newColumns.length !== tableRef.current.getColumns().length) {
        tableRef.current.setColumns(newColumns);
      }

      // Update height
      if (tableRef.current.options.height !== newHeight) {
        tableRef.current.setHeight(newHeight);
      }

      // Scroll to bottom
      if (tableRef.current.getRows().length === oldRows.length + 1) {
        setTimeout(() => {
          const rows = tableRef.current!.getRows()!;
          const lastRow = rows[rows.length - 1]!;
          lastRow.scrollTo().then((r) => {});
          lastRow.getCell("Name").edit();
        }, 10);
      }

      // Update callbacks
      tableRef.current.off("cellEdited");
      tableRef.current.on("cellEdited", (cell) => {
        onCellEdited(cell);
      });
    }
  }, [props, isTableBuilt]);

  return <div className="tableContainer" ref={tableContainerRef} />;
};

export default DataTable;
