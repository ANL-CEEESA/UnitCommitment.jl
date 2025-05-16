/*
 * UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
 * Copyright (C) 2020-2025, UChicago Argonne, LLC. All rights reserved.
 * Released under the modified BSD license. See COPYING.md for more details.
 */

import SectionHeader from "../Common/SectionHeader/SectionHeader";
import { UnitCommitmentScenario } from "../../core/fixtures";
import BusesTable, { generateBusesCsv, parseBusesCsv } from "./BusesTable";
import SectionButton from "../Common/Buttons/SectionButton";
import {
  faDownload,
  faPlus,
  faUpload,
} from "@fortawesome/free-solid-svg-icons";
import { offerDownload } from "../Common/io";
import FileUploadElement from "../Common/Buttons/FileUploadElement";
import { useRef } from "react";
import { ValidationError } from "../../core/Validation/validate";

interface BusesProps {
  scenario: UnitCommitmentScenario;
  onBusCreated: () => void;
  onBusDataChanged: (
    bus: string,
    field: string,
    newValue: string,
  ) => ValidationError | null;
  onBusDeleted: (bus: string) => void;
  onBusRenamed: (oldName: string, newName: string) => ValidationError | null;
  onDataChanged: (scenario: UnitCommitmentScenario) => void;
}

function BusesComponent(props: BusesProps) {
  const fileUploadElem = useRef<FileUploadElement>(null);

  const onDownload = () => {
    const csvContents = generateBusesCsv(props.scenario);
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
      <BusesTable
        scenario={props.scenario}
        onBusDataChanged={props.onBusDataChanged}
        onBusDeleted={props.onBusDeleted}
        onBusRenamed={props.onBusRenamed}
      />
      <FileUploadElement ref={fileUploadElem} accept=".csv" />
    </div>
  );
}

export default BusesComponent;
