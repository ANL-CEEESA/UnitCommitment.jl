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
} from "../../Common/Forms/DataTable";
import { UnitCommitmentScenario } from "../../../core/fixtures";
import { ColumnDefinition } from "tabulator-tables";
import { offerDownload } from "../../Common/io";

interface ProfiledUnitsProps {
  scenario: UnitCommitmentScenario;
  onProfiledUnitCreated: () => void;
}

const generateProfiledUnitsData = (
  scenario: UnitCommitmentScenario,
): [any[], ColumnDefinition[]] => {
  const colSpecs: ColumnSpec[] = [
    {
      title: "Name",
      type: "string",
      width: 150,
    },
    {
      title: "Bus",
      type: "string",
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
  const columns = generateTableColumns(scenario, colSpecs);
  const data = generateTableData(scenario.Generators, colSpecs, scenario);
  return [data, columns];
};

const ProfiledUnitsComponent = (props: ProfiledUnitsProps) => {
  const onDownload = () => {
    const [data, columns] = generateProfiledUnitsData(props.scenario);
    const csvContents = generateCsv(data, columns);
    offerDownload(csvContents, "text/csv", "profiled_units.csv");
  };
  const onUpload = () => {};
  return (
    <div>
      <SectionHeader title="Profiled Units">
        <SectionButton
          icon={faPlus}
          tooltip="Add"
          onClick={props.onProfiledUnitCreated}
        />
        <SectionButton
          icon={faDownload}
          tooltip="Download"
          onClick={onDownload}
        />
        <SectionButton icon={faUpload} tooltip="Upload" onClick={onUpload} />
      </SectionHeader>
      <DataTable
        onRowDeleted={() => {
          return null;
        }}
        onRowRenamed={() => {
          return null;
        }}
        onDataChanged={() => {
          return null;
        }}
        generateData={() => generateProfiledUnitsData(props.scenario)}
      />
    </div>
  );
};

export default ProfiledUnitsComponent;
