/*
 * UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
 * Copyright (C) 2020-2025, UChicago Argonne, LLC. All rights reserved.
 * Released under the modified BSD license. See COPYING.md for more details.
 */

import SectionHeader from "../Common/SectionHeader/SectionHeader";
import SectionButton from "../Common/Buttons/SectionButton";
import { faDownload, faPlus, faUpload } from "@fortawesome/free-solid-svg-icons";
import { offerDownload } from "../Common/io";
import FileUploadElement from "../Common/Buttons/FileUploadElement";
import { useRef } from "react";
import { ValidationError } from "../../core/Data/validate";
import DataTable, {
  ColumnSpec,
  generateCsv,
  generateTableColumns,
  generateTableData,
  parseCsv
} from "../Common/Forms/DataTable";

import { ColumnDefinition } from "tabulator-tables";
import { changeBusData, createBus, deleteBus, renameBus } from "../../core/Operations/busOps";
import { CaseBuilderSectionProps } from "./CaseBuilder";
import { UnitCommitmentScenario } from "../../core/Data/types";

export const BusesColumnSpec: ColumnSpec[] = [
  {
    title: "Name",
    type: "string",
    width: 100,
  },
  {
    title: "Load (MW)",
    type: "number[T]",
    width: 60,
  },
];

export const generateBusesData = (
  scenario: UnitCommitmentScenario,
): [any[], ColumnDefinition[]] => {
  const columns = generateTableColumns(scenario, BusesColumnSpec);
  const data = generateTableData(scenario.Buses, BusesColumnSpec, scenario);
  return [data, columns];
};

function BusesComponent(props: CaseBuilderSectionProps) {
  const fileUploadElem = useRef<FileUploadElement>(null);

  const onSave = () => {
    const [data, columns] = generateBusesData(props.scenario);
    const csvContents = generateCsv(data, columns);
    offerDownload(csvContents, "text/csv", "buses.csv");
  };

  const onLoad = () => {
    fileUploadElem.current!.showFilePicker((csvContents: any) => {
      const [newBuses, err] = parseCsv(
        csvContents,
        BusesColumnSpec,
        props.scenario,
      );
      if (err) {
        props.onError(err.message);
        return;
      }
      const newScenario = {
        ...props.scenario,
        Buses: newBuses,
      };
      props.onDataChanged(newScenario);
    });
  };

  const onAdd = () => {
    const newScenario = createBus(props.scenario);
    props.onDataChanged(newScenario);
  };

  const onDataChanged = (
    bus: string,
    field: string,
    newValue: string,
  ): ValidationError | null => {
    const [newScenario, err] = changeBusData(
      bus,
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

  const onDelete = (bus: string): ValidationError | null => {
    const newScenario = deleteBus(bus, props.scenario);
    props.onDataChanged(newScenario);
    return null;
  };

  const onRename = (
    oldName: string,
    newName: string,
  ): ValidationError | null => {
    const [newScenario, err] = renameBus(oldName, newName, props.scenario);
    if (err) {
      props.onError(err.message);
      return err;
    }
    props.onDataChanged(newScenario);
    return null;
  };

  return (
    <div>
      <SectionHeader title="Buses">
        <SectionButton icon={faUpload} tooltip="Load" onClick={onLoad} />
        <SectionButton
          icon={faDownload}
          tooltip="Save"
          onClick={onSave}
        />
        <SectionButton icon={faPlus} tooltip="Add" onClick={onAdd} />
      </SectionHeader>
      <DataTable
        onRowDeleted={onDelete}
        onRowRenamed={onRename}
        onDataChanged={onDataChanged}
        generateData={() => generateBusesData(props.scenario)}
      />
      <FileUploadElement ref={fileUploadElem} accept=".csv" />
    </div>
  );
}

export default BusesComponent;
