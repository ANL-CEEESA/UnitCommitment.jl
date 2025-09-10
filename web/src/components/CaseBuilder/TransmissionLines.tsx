/*
 * UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
 * Copyright (C) 2020-2025, UChicago Argonne, LLC. All rights reserved.
 * Released under the modified BSD license. See COPYING.md for more details.
 */

import SectionHeader from "../Common/SectionHeader/SectionHeader";
import SectionButton from "../Common/Buttons/SectionButton";
import {
  faDownload,
  faPlus,
  faUpload,
} from "@fortawesome/free-solid-svg-icons";
import DataTable, {
  ColumnSpec,
  generateCsv,
  generateTableColumns,
  generateTableData,
  parseCsv,
} from "../Common/Forms/DataTable";
import { ColumnDefinition } from "tabulator-tables";
import FileUploadElement from "../Common/Buttons/FileUploadElement";
import { useRef } from "react";
import { ValidationError } from "../../core/Data/validate";
import { CaseBuilderSectionProps } from "./CaseBuilder";
import {
  changeTransmissionLineData,
  createTransmissionLine,
  deleteTransmissionLine,
  renameTransmissionLine,
} from "../../core/Operations/transmissionOps";
import { offerDownload } from "../Common/io";
import { UnitCommitmentScenario } from "../../core/Data/types";

export const TransmissionLinesColumnSpec: ColumnSpec[] = [
  {
    title: "Name",
    type: "string",
    width: 100,
  },
  {
    title: "Source bus",
    type: "busRef",
    width: 100,
  },
  {
    title: "Target bus",
    type: "busRef",
    width: 100,
  },
  {
    title: "Susceptance (S)",
    type: "number",
    width: 60,
  },
  {
    title: "Normal flow limit (MW)",
    type: "number?",
    width: 60,
  },
  {
    title: "Emergency flow limit (MW)",
    type: "number?",
    width: 60,
  },
  {
    title: "Flow limit penalty ($/MW)",
    type: "number",
    width: 60,
  },
];

const generateTransmissionLinesData = (
  scenario: UnitCommitmentScenario,
): [any[], ColumnDefinition[]] => {
  const columns = generateTableColumns(scenario, TransmissionLinesColumnSpec);
  const data = generateTableData(
    scenario["Transmission lines"],
    TransmissionLinesColumnSpec,
    scenario,
  );
  return [data, columns];
};

const TransmissionLinesComponent = (props: CaseBuilderSectionProps) => {
  const fileUploadElem = useRef<FileUploadElement>(null);

  const onDownload = () => {
    const [data, columns] = generateTransmissionLinesData(props.scenario);
    const csvContents = generateCsv(data, columns);
    offerDownload(csvContents, "text/csv", "transmission.csv");
  };

  const onUpload = () => {
    fileUploadElem.current!.showFilePicker((csv: any) => {
      const [newLines, err] = parseCsv(
        csv,
        TransmissionLinesColumnSpec,
        props.scenario,
      );
      if (err) {
        props.onError(err.message);
        return;
      }
      const newScenario = {
        ...props.scenario,
        "Transmission lines": newLines,
      };
      props.onDataChanged(newScenario);
    });
  };

  const onAdd = () => {
    const [newScenario, err] = createTransmissionLine(props.scenario);
    if (err) {
      props.onError(err.message);
      return;
    }
    props.onDataChanged(newScenario);
  };

  const onDelete = (name: string): ValidationError | null => {
    const newScenario = deleteTransmissionLine(name, props.scenario);
    props.onDataChanged(newScenario);
    return null;
  };

  const onDataChanged = (
    name: string,
    field: string,
    newValue: string,
  ): ValidationError | null => {
    const [newScenario, err] = changeTransmissionLineData(
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
    const [newScenario, err] = renameTransmissionLine(
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
      <SectionHeader title="Transmission lines">
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
        generateData={() => generateTransmissionLinesData(props.scenario)}
      />
      <FileUploadElement ref={fileUploadElem} accept=".csv" />
    </div>
  );
};

export default TransmissionLinesComponent;
