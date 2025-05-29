/*
 * UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
 * Copyright (C) 2020-2025, UChicago Argonne, LLC. All rights reserved.
 * Released under the modified BSD license. See COPYING.md for more details.
 */

import SectionHeader from "../../Common/SectionHeader/SectionHeader";
import SectionButton from "../../Common/Buttons/SectionButton";
import {
  faDownload,
  faPlus,
  faUpload,
} from "@fortawesome/free-solid-svg-icons";
import { offerDownload } from "../../Common/io";
import FileUploadElement from "../../Common/Buttons/FileUploadElement";
import { useRef } from "react";
import { ValidationError } from "../../../core/Validation/validate";
import DataTable, {
  addNameColumn,
  addTimeseriesColumn,
  ColumnSpec,
  generateCsv,
  generateTableColumns,
  generateTableData,
} from "../../Common/Forms/DataTable";

import { UnitCommitmentScenario } from "../../../core/fixtures";
import { ColumnDefinition } from "tabulator-tables";
import { parseBusesCsv } from "./BusesCsv";

export const generateBusesData = (
  scenario: UnitCommitmentScenario,
): [any[], ColumnDefinition[]] => {
  const colSpecs: ColumnSpec[] = [
    {
      title: "Name",
      type: "string",
      width: 150,
    },
    {
      title: "Load (MW)",
      type: "number[]",
      width: 60,
    },
  ];
  const columns = generateTableColumns(scenario, colSpecs);
  const data = generateTableData(scenario.Buses, colSpecs, scenario);
  return [data, columns];
};

export const generateBusesColumns = (
  scenario: UnitCommitmentScenario,
): ColumnDefinition[] => {
  const columns: ColumnDefinition[] = [];
  addNameColumn(columns);
  addTimeseriesColumn(scenario, "Load (MW)", columns);
  return columns;
};

interface BusesProps {
  scenario: UnitCommitmentScenario;
  onBusCreated: () => void;
  onBusDataChanged: (
    bus: string,
    field: string,
    newValue: string,
  ) => ValidationError | null;
  onBusDeleted: (bus: string) => ValidationError | null;
  onBusRenamed: (oldName: string, newName: string) => ValidationError | null;
  onDataChanged: (scenario: UnitCommitmentScenario) => void;
}

function BusesComponent(props: BusesProps) {
  const fileUploadElem = useRef<FileUploadElement>(null);

  const onDownload = () => {
    const [data, columns] = generateBusesData(props.scenario);
    const csvContents = generateCsv(data, columns);
    offerDownload(csvContents, "text/csv", "buses.csv");
  };

  const onUpload = () => {
    fileUploadElem.current!.showFilePicker((csvContents: any) => {
      const newScenario = parseBusesCsv(props.scenario, csvContents);
      props.onDataChanged(newScenario);
    });
  };

  return (
    <div>
      <SectionHeader title="Buses">
        <SectionButton
          icon={faPlus}
          tooltip="Add"
          onClick={props.onBusCreated}
        />
        <SectionButton
          icon={faDownload}
          tooltip="Download"
          onClick={onDownload}
        />
        <SectionButton icon={faUpload} tooltip="Upload" onClick={onUpload} />
      </SectionHeader>
      <DataTable
        onRowDeleted={props.onBusDeleted}
        onRowRenamed={props.onBusRenamed}
        onDataChanged={props.onBusDataChanged}
        generateData={() => generateBusesData(props.scenario)}
      />
      <FileUploadElement ref={fileUploadElem} accept=".csv" />
    </div>
  );
}

export default BusesComponent;
