/*
 * UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
 * Copyright (C) 2020-2025, UChicago Argonne, LLC. All rights reserved.
 * Released under the modified BSD license. See COPYING.md for more details.
 */

import Header from "./Header";
import Parameters from "./Parameters";
import BusesComponent from "./Buses";
import { BLANK_SCENARIO } from "../../core/Data/fixtures";

import "tabulator-tables/dist/css/tabulator.min.css";
import "../Common/Forms/Tables.css";
import { useState } from "react";
import { useNavigate } from "react-router";
import Footer from "../Common/Footer";
import * as pako from "pako";
import { offerDownload } from "../Common/io";
import { preprocess } from "../../core/Operations/preprocessing";
import Toast from "../Common/Forms/Toast";
import ProfiledUnitsComponent from "./ProfiledUnits";
import ThermalUnitsComponent from "./ThermalUnits";
import TransmissionLinesComponent from "./TransmissionLines";
import { UnitCommitmentScenario } from "../../core/Data/types";
import StorageComponent from "./StorageUnits";
import PriceSensitiveLoadsComponent from "./Psload";

export interface CaseBuilderSectionProps {
  scenario: UnitCommitmentScenario;
  onDataChanged: (scenario: UnitCommitmentScenario) => void;
  onError: (msg: string) => void;
}

const CaseBuilder = () => {
  const navigate = useNavigate();
  const [scenario, setScenario] = useState(() => {
    const savedScenario = localStorage.getItem("scenario");
    if (!savedScenario) return BLANK_SCENARIO;
    const [processedScenario, err] = preprocess(JSON.parse(savedScenario));
    if (err) {
      console.log(err);
      return BLANK_SCENARIO;
    }
    return processedScenario!!;
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

  const onLoad = (data: any) => {
    const json = JSON.parse(data);
    const [scenario, err] = preprocess(json);
    if (err) {
      setToastMessage(err.message);
      return;
    }
    setAndSaveScenario(scenario!);
    setToastMessage("Data loaded successfully");
  };

  const onUndo = () => {
    if (undoStack.length === 0) return;
    setUndoStack(undoStack.slice(0, -1));
    setAndSaveScenario(undoStack[undoStack.length - 1]!, false);
  };

  const onSolve = async () => {
    // Compress scenario
    const jsonString = JSON.stringify(scenario);
    const compressed = pako.gzip(jsonString);

    // POST to backend
    const backendUrl = process.env.REACT_APP_BACKEND_URL;
    const response = await fetch(`${backendUrl}/submit`, {
      method: "POST",
      headers: {
        "Content-Type": "application/gzip",
      },
      body: compressed,
    });

    // Error handling
    if (!response.ok) {
      setToastMessage("Failed to submit file. See console for more details.");
      console.log(response);
      return;
    }

    // Parse response
    const data = await response.json();
    navigate(`/jobs/${data.job_id}`);
  };

  return (
    <div>
      <Header
        onClear={onClear}
        onSave={onSave}
        onLoad={onLoad}
        onUndo={onUndo}
        onSolve={onSolve}
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
        <StorageComponent
          scenario={scenario}
          onDataChanged={onDataChanged}
          onError={setToastMessage}
        />
        <PriceSensitiveLoadsComponent
          scenario={scenario}
          onDataChanged={onDataChanged}
          onError={setToastMessage}
        />
        <TransmissionLinesComponent
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
