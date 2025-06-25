/*
 * UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
 * Copyright (C) 2020-2025, UChicago Argonne, LLC. All rights reserved.
 * Released under the modified BSD license. See COPYING.md for more details.
 */

import Header from "./Header";
import Parameters from "./Parameters";
import BusesComponent from "./Buses";
import {
  BLANK_SCENARIO,
  TEST_SCENARIO,
  UnitCommitmentScenario,
} from "../../core/fixtures";

import "tabulator-tables/dist/css/tabulator.min.css";
import "../Common/Forms/Tables.css";
import { useState } from "react";
import Footer from "./Footer";
import { validate } from "../../core/Validation/validate";
import { offerDownload } from "../Common/io";
import { preprocess } from "../../core/Operations/preprocessing";
import Toast from "../Common/Forms/Toast";
import ProfiledUnitsComponent from "./ProfiledUnits";
import ThermalUnitsComponent from "./ThermalUnits";

export interface CaseBuilderSectionProps {
  scenario: UnitCommitmentScenario;
  onDataChanged: (scenario: UnitCommitmentScenario) => void;
  onError: (msg: string) => void;
}

const CaseBuilder = () => {
  const [scenario, setScenario] = useState(() => {
    // const savedScenario = localStorage.getItem("scenario");
    // return savedScenario ? JSON.parse(savedScenario) : TEST_SCENARIO;
    return TEST_SCENARIO;
  });
  const [undoStack, setUndoStack] = useState<UnitCommitmentScenario[]>([]);
  const [toastMessage, setToastMessage] = useState<string>("");

  const setAndSaveScenario = (
    newScenario: UnitCommitmentScenario,
    updateUndoStack = true,
  ) => {
    if (updateUndoStack) {
      const newUndoStack = [...undoStack, scenario];
      if (newUndoStack.length > 25) {
        newUndoStack.splice(0, newUndoStack.length - 25);
      }
      setUndoStack(newUndoStack);
    }
    setScenario(newScenario);
    localStorage.setItem("scenario", JSON.stringify(newScenario));
  };

  const onClear = () => {
    setAndSaveScenario(BLANK_SCENARIO);
  };

  const onSave = () => {
    offerDownload(
      JSON.stringify(scenario, null, 2),
      "application/json",
      "case.json",
    );
  };

  const onDataChanged = (newScenario: UnitCommitmentScenario) => {
    setAndSaveScenario(newScenario);
  };

  const onLoad = (scenario: UnitCommitmentScenario) => {
    const preprocessed = preprocess(
      scenario,
    ) as unknown as UnitCommitmentScenario;

    // Validate and assign default values
    if (!validate(preprocessed)) {
      setToastMessage("Error loading JSON file");
      console.error(validate.errors);
      return;
    }

    setAndSaveScenario(preprocessed);
    setToastMessage("Data loaded successfully");
  };

  const onUndo = () => {
    if (undoStack.length === 0) return;
    setUndoStack(undoStack.slice(0, -1));
    setAndSaveScenario(undoStack[undoStack.length - 1]!, false);
  };

  return (
    <div>
      <Header
        onClear={onClear}
        onSave={onSave}
        onLoad={onLoad}
        onUndo={onUndo}
      />
      <div className="content">
        <Parameters
          scenario={scenario}
          onDataChanged={onDataChanged}
          onError={setToastMessage}
        />
        <BusesComponent
          scenario={scenario}
          onDataChanged={onDataChanged}
          onError={setToastMessage}
        />
        <ThermalUnitsComponent
          scenario={scenario}
          onDataChanged={onDataChanged}
          onError={setToastMessage}
        />
        <ProfiledUnitsComponent
          scenario={scenario}
          onDataChanged={onDataChanged}
          onError={setToastMessage}
        />
        <Toast message={toastMessage} />
      </div>
      <Footer />
    </div>
  );
};

export default CaseBuilder;
