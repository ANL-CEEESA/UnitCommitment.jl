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
import DataTable, {
  ColumnSpec,
  generateCsv,
  generateTableColumns,
  generateTableData,
  parseCsv,
} from "../../Common/Forms/DataTable";
import { UnitCommitmentScenario } from "../../../core/fixtures";
import { ColumnDefinition } from "tabulator-tables";
import { offerDownload } from "../../Common/io";
import FileUploadElement from "../../Common/Buttons/FileUploadElement";
import { useRef } from "react";
import {
  changeProfiledUnitData,
  createProfiledUnit,
  deleteGenerator,
  renameGenerator,
} from "../../../core/Operations/generatorOps";
import { ValidationError } from "../../../core/Validation/validate";

interface ProfiledUnitsProps {
  scenario: UnitCommitmentScenario;
  onDataChanged: (scenario: UnitCommitmentScenario) => void;
  onError: (msg: string) => void;
}

export const ProfiledUnitsColumnSpec: ColumnSpec[] = [
  {
    title: "Name",
    type: "string",
    width: 150,
  },
  {
    title: "Bus",
    type: "busRef",
    width: 150,
  },
  {
    title: "Cost ($/MW)",
    type: "number",
    width: 100,
  },
  {
    title: "Maximum power (MW)",
    type: "number[]",
    width: 60,
  },
  {
    title: "Minimum power (MW)",
    type: "number[]",
    width: 60,
  },
];

const generateProfiledUnitsData = (
  scenario: UnitCommitmentScenario,
): [any[], ColumnDefinition[]] => {
  const columns = generateTableColumns(scenario, ProfiledUnitsColumnSpec);
  const data = generateTableData(
    scenario.Generators,
    ProfiledUnitsColumnSpec,
    scenario,
  );
  return [data, columns];
};

const ProfiledUnitsComponent = (props: ProfiledUnitsProps) => {
  const fileUploadElem = useRef<FileUploadElement>(null);

  const onDownload = () => {
    const [data, columns] = generateProfiledUnitsData(props.scenario);
    const csvContents = generateCsv(data, columns);
    offerDownload(csvContents, "text/csv", "profiled_units.csv");
  };

  const onUpload = () => {
    fileUploadElem.current!.showFilePicker((csvContents: any) => {
      const [newGenerators, err] = parseCsv(
        csvContents,
        ProfiledUnitsColumnSpec,
        props.scenario,
      );
      if (err) {
        props.onError(err.message);
        return;
      }
      for (const gen in newGenerators) {
        newGenerators[gen]["Type"] = "Profiled";
      }

      const newScenario = {
        ...props.scenario,
        Generators: newGenerators,
      };
      props.onDataChanged(newScenario);
    });
  };

  const onAdd = () => {
    const [newScenario, err] = createProfiledUnit(props.scenario);
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
    const [newScenario, err] = changeProfiledUnitData(
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
      <SectionHeader title="Profiled Units">
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
        generateData={() => generateProfiledUnitsData(props.scenario)}
      />
      <FileUploadElement ref={fileUploadElem} accept=".csv" />
    </div>
  );
};

export default ProfiledUnitsComponent;
