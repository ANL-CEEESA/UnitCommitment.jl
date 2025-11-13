/*
 * UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
 * Copyright (C) 2020-2025, UChicago Argonne, LLC. All rights reserved.
 * Released under the modified BSD license. See COPYING.md for more details.
 */

import DataTable, {
  ColumnSpec,
  generateCsv,
  generateTableColumns,
  generateTableData,
  parseCsv,
} from "../Common/Forms/DataTable";
import { CaseBuilderSectionProps } from "./CaseBuilder";
import { useRef } from "react";
import FileUploadElement from "../Common/Buttons/FileUploadElement";
import { ValidationError } from "../../core/Data/validate";
import SectionHeader from "../Common/SectionHeader/SectionHeader";
import SectionButton from "../Common/Buttons/SectionButton";
import {
  faDownload,
  faPlus,
  faUpload,
} from "@fortawesome/free-solid-svg-icons";
import { UnitCommitmentScenario } from "../../core/Data/types";
import { ColumnDefinition } from "tabulator-tables";
import {
  changeStorageUnitData,
  createStorageUnit,
  deleteStorageUnit,
  renameStorageUnit,
} from "../../core/Operations/storageOps";
import { offerDownload } from "../Common/io";

export const StorageUnitsColumnSpec: ColumnSpec[] = [
  {
    title: "Name",
    type: "string",
    width: 100,
  },
  {
    title: "Bus",
    type: "busRef",
    width: 100,
  },
  {
    title: "Minimum level (MWh)",
    type: "number",
    width: 100,
  },
  {
    title: "Maximum level (MWh)",
    type: "number",
    width: 100,
  },
  {
    title: "Charge cost ($/MW)",
    type: "number",
    width: 100,
  },
  {
    title: "Discharge cost ($/MW)",
    type: "number",
    width: 100,
  },
  {
    title: "Charge efficiency",
    type: "number",
    width: 100,
  },
  {
    title: "Discharge efficiency",
    type: "number",
    width: 100,
  },
  {
    title: "Loss factor",
    type: "number",
    width: 80,
  },
  {
    title: "Minimum charge rate (MW)",
    type: "number",
    width: 140,
  },
  {
    title: "Maximum charge rate (MW)",
    type: "number",
    width: 140,
  },
  {
    title: "Minimum discharge rate (MW)",
    type: "number",
    width: 140,
  },
  {
    title: "Maximum discharge rate (MW)",
    type: "number",
    width: 150,
  },
  {
    title: "Initial level (MWh)",
    type: "number",
    width: 100,
  },
  {
    title: "Last period minimum level (MWh)",
    type: "number",
    width: 160,
  },
  {
    title: "Last period maximum level (MWh)",
    type: "number",
    width: 160,
  },
];

export const generateStorageUnitsData = (
  scenario: UnitCommitmentScenario,
): [any[], ColumnDefinition[]] => {
  const columns = generateTableColumns(scenario, StorageUnitsColumnSpec);
  const data = generateTableData(
    scenario["Storage units"],
    StorageUnitsColumnSpec,
    scenario,
  );
  return [data, columns];
};

const StorageUnitsComponent = (props: CaseBuilderSectionProps) => {
  const fileUploadElem = useRef<FileUploadElement>(null);

  const onDownload = () => {
    const [data, columns] = generateStorageUnitsData(props.scenario);
    const csvContents = generateCsv(data, columns);
    offerDownload(csvContents, "text/csv", "storage_units.csv");
  };

  const onUpload = () => {
    fileUploadElem.current!.showFilePicker((csv: any) => {
      // Parse provided CSV file
      const [storageUnits, err] = parseCsv(
        csv,
        StorageUnitsColumnSpec,
        props.scenario,
      );

      // Handle validation errors
      if (err) {
        props.onError(err.message);
        return;
      }

      // Generate new scenario
      props.onDataChanged({
        ...props.scenario,
        "Storage units": storageUnits,
      });
    });
  };

  const onAdd = () => {
    const [newScenario, err] = createStorageUnit(props.scenario);
    if (err) {
      props.onError(err.message);
      return;
    }
    props.onDataChanged(newScenario);
  };

  const onDelete = (name: string): ValidationError | null => {
    const newScenario = deleteStorageUnit(name, props.scenario);
    props.onDataChanged(newScenario);
    return null;
  };

  const onDataChanged = (
    name: string,
    field: string,
    newValue: string,
  ): ValidationError | null => {
    const [newScenario, err] = changeStorageUnitData(
      name,
      field,
      newValue,
      props.scenario,
    );
    if (err) {
      props.onError(err.message);
      return err;
    }
    props.onDataChanged(newScenario);
    return null;
  };

  const onRename = (
    oldName: string,
    newName: string,
  ): ValidationError | null => {
    const [newScenario, err] = renameStorageUnit(
      oldName,
      newName,
      props.scenario,
    );
    if (err) {
      props.onError(err.message);
      return err;
    }
    props.onDataChanged(newScenario);
    return null;
  };

  return (
    <div>
      <SectionHeader title="Storage units">
        <SectionButton icon={faUpload} tooltip="Upload" onClick={onUpload} />
        <SectionButton
          icon={faDownload}
          tooltip="Download"
          onClick={onDownload}
        />
        <SectionButton icon={faPlus} tooltip="Add" onClick={onAdd} />
      </SectionHeader>
      <DataTable
        onRowDeleted={onDelete}
        onRowRenamed={onRename}
        onDataChanged={onDataChanged}
        generateData={() => generateStorageUnitsData(props.scenario)}
      />
      <FileUploadElement ref={fileUploadElem} accept=".csv" />
    </div>
  );
};

export default StorageUnitsComponent;
