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
  changePriceSensitiveLoadData,
  createPriceSensitiveLoad,
  deletePriceSensitiveLoad,
  renamePriceSensitiveLoad,
} from "../../core/Operations/psloadOps";
import { offerDownload } from "../Common/io";

export const PriceSensitiveLoadsColumnSpec: ColumnSpec[] = [
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
    title: "Revenue ($/MW)",
    type: "number",
    width: 100,
  },
  {
    title: "Demand (MW)",
    type: "number[T]",
    width: 70,
  },
];

export const generatePriceSensitiveLoadsData = (
  scenario: UnitCommitmentScenario,
): [any[], ColumnDefinition[]] => {
  const columns = generateTableColumns(scenario, PriceSensitiveLoadsColumnSpec);
  const data = generateTableData(
    scenario["Price-sensitive loads"],
    PriceSensitiveLoadsColumnSpec,
    scenario,
  );
  return [data, columns];
};

const PriceSensitiveLoadsComponent = (props: CaseBuilderSectionProps) => {
  const fileUploadElem = useRef<FileUploadElement>(null);

  const onDownload = () => {
    const [data, columns] = generatePriceSensitiveLoadsData(props.scenario);
    const csvContents = generateCsv(data, columns);
    offerDownload(csvContents, "text/csv", "psloads.csv");
  };

  const onUpload = () => {
    fileUploadElem.current!.showFilePicker((csv: any) => {
      // Parse provided CSV file
      const [psloads, err] = parseCsv(
        csv,
        PriceSensitiveLoadsColumnSpec,
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
        "Price-sensitive loads": psloads,
      });
    });
  };

  const onAdd = () => {
    const [newScenario, err] = createPriceSensitiveLoad(props.scenario);
    if (err) {
      props.onError(err.message);
      return;
    }
    props.onDataChanged(newScenario);
  };

  const onDelete = (name: string): ValidationError | null => {
    const newScenario = deletePriceSensitiveLoad(name, props.scenario);
    props.onDataChanged(newScenario);
    return null;
  };

  const onDataChanged = (
    name: string,
    field: string,
    newValue: string,
  ): ValidationError | null => {
    const [newScenario, err] = changePriceSensitiveLoadData(
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
    const [newScenario, err] = renamePriceSensitiveLoad(
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
      <SectionHeader title="Price-sensitive loads">
        <SectionButton icon={faPlus} tooltip="Add" onClick={onAdd} />
        <SectionButton
          icon={faDownload}
          tooltip="Download"
          onClick={onDownload}
        />
        <SectionButton icon={faUpload} tooltip="Upload" onClick={onUpload} />
      </SectionHeader>
      <DataTable
        onRowDeleted={onDelete}
        onRowRenamed={onRename}
        onDataChanged={onDataChanged}
        generateData={() => generatePriceSensitiveLoadsData(props.scenario)}
      />
      <FileUploadElement ref={fileUploadElem} accept=".csv" />
    </div>
  );
};

export default PriceSensitiveLoadsComponent;
