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
} from "../Common/Forms/DataTable";
import { CaseBuilderSectionProps } from "./CaseBuilder";
import { useRef } from "react";
import FileUploadElement from "../Common/Buttons/FileUploadElement";
import { ValidationError } from "../../core/Validation/validate";
import SectionHeader from "../Common/SectionHeader/SectionHeader";
import SectionButton from "../Common/Buttons/SectionButton";
import {
  faDownload,
  faPlus,
  faUpload,
} from "@fortawesome/free-solid-svg-icons";
import {
  getThermalGenerators,
  UnitCommitmentScenario,
} from "../../core/fixtures";
import { ColumnDefinition } from "tabulator-tables";
import { offerDownload } from "../Common/io";
import {
  createThermalUnit,
  deleteGenerator,
  renameGenerator,
} from "../../core/Operations/generatorOps";

export const ThermalUnitsColumnSpec: ColumnSpec[] = [
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
    title: "Production cost curve (MW)",
    type: "number[N]",
    length: 10,
    width: 60,
  },
  {
    title: "Production cost curve ($)",
    type: "number[N]",
    length: 10,
    width: 60,
  },
  {
    title: "Startup costs ($)",
    type: "number[N]",
    length: 5,
    width: 60,
  },
  {
    title: "Startup delays (h)",
    type: "number[N]",
    length: 5,
    width: 60,
  },
  {
    title: "Minimum uptime (h)",
    type: "number",
    width: 80,
  },
  {
    title: "Minimum downtime (h)",
    type: "number",
    width: 100,
  },
  {
    title: "Ramp up limit (MW)",
    type: "number",
    width: 100,
  },
  {
    title: "Ramp down limit (MW)",
    type: "number",
    width: 100,
  },
  {
    title: "Startup limit (MW)",
    type: "number",
    width: 80,
  },
  {
    title: "Shutdown limit (MW)",
    type: "number",
    width: 100,
  },
  {
    title: "Initial status (h)",
    type: "number",
    width: 80,
  },
  {
    title: "Initial power (MW)",
    type: "number",
    width: 100,
  },
  {
    title: "Must run?",
    type: "boolean",
    width: 80,
  },
];

const generateThermalUnitsData = (
  scenario: UnitCommitmentScenario,
): [any[], ColumnDefinition[]] => {
  const columns = generateTableColumns(scenario, ThermalUnitsColumnSpec);
  const data = generateTableData(
    getThermalGenerators(scenario),
    ThermalUnitsColumnSpec,
    scenario,
  );
  return [data, columns];
};

const ThermalUnitsComponent = (props: CaseBuilderSectionProps) => {
  const fileUploadElem = useRef<FileUploadElement>(null);

  const onDownload = () => {
    const [data, columns] = generateThermalUnitsData(props.scenario);
    const csvContents = generateCsv(data, columns);
    offerDownload(csvContents, "text/csv", "thermal_units.csv");
  };

  const onUpload = () => {
    // fileUploadElem.current!.showFilePicker((csvContents: any) => {
    //   const [newGenerators, err] = parseCsv(
    //     csvContents,
    //     ThermalUnitsColumnSpec,
    //     props.scenario,
    //   );
    //   if (err) {
    //     props.onError(err.message);
    //     return;
    //   }
    //   for (const gen in newGenerators) {
    //     newGenerators[gen]["Type"] = "Thermal";
    //   }
    //
    //   const newScenario = {
    //     ...props.scenario,
    //     Generators: newGenerators,
    //   };
    //   props.onDataChanged(newScenario);
    // });
  };

  const onAdd = () => {
    const [newScenario, err] = createThermalUnit(props.scenario);
    if (err) {
      props.onError(err.message);
      return;
    }
    props.onDataChanged(newScenario);
  };

  const onDelete = (name: string): ValidationError | null => {
    const newScenario = deleteGenerator(name, props.scenario);
    props.onDataChanged(newScenario);
    return null;
  };

  const onDataChanged = (
    name: string,
    field: string,
    newValue: string,
  ): ValidationError | null => {
    //   const [newScenario, err] = changeThermalUnitData(
    //     name,
    //     field,
    //     newValue,
    //     props.scenario,
    //   );
    //   if (err) {
    //     props.onError(err.message);
    //     return err;
    //   }
    //   props.onDataChanged(newScenario);
    return null;
  };

  const onRename = (
    oldName: string,
    newName: string,
  ): ValidationError | null => {
    const [newScenario, err] = renameGenerator(
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
      <SectionHeader title="Thermal Units">
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
        generateData={() => generateThermalUnitsData(props.scenario)}
      />
      <FileUploadElement ref={fileUploadElem} accept=".csv" />
    </div>
  );
};

export default ThermalUnitsComponent;
