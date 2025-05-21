/*
 * UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
 * Copyright (C) 2020-2025, UChicago Argonne, LLC. All rights reserved.
 * Released under the modified BSD license. See COPYING.md for more details.
 */

import Header from "./Header";
import Parameters from "./Parameters";
import BusesComponent from "./BusesComponent";
import {
  BLANK_SCENARIO,
  TEST_SCENARIO,
  UnitCommitmentScenario,
} from "../../core/fixtures";

import "tabulator-tables/dist/css/tabulator.min.css";
import "../Common/Forms/Tables.css";
import { useState } from "react";
import Footer from "./Footer";
import { validate, ValidationError } from "../../core/Validation/validate";
import { offerDownload } from "../Common/io";
import {
  changeBusData,
  createBus,
  deleteBus,
  renameBus,
} from "../../core/Operations/busOperations";
import {
  changeParameter,
  changeTimeHorizon,
  changeTimeStep,
} from "../../core/Operations/parameterOperations";
import { preprocess } from "../../core/Operations/preprocessing";
import Toast from "../Common/Forms/Toast";

const CaseBuilder = () => {
  const [scenario, setScenario] = useState(() => {
    const savedScenario = localStorage.getItem("scenario");
    return savedScenario ? JSON.parse(savedScenario) : TEST_SCENARIO;
  });
  const [toastMessage, setToastMessage] = useState<string>("");

  const setAndSaveScenario = (scenario: UnitCommitmentScenario) => {
    setScenario(scenario);
    localStorage.setItem("scenario", JSON.stringify(scenario));
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

  const onBusCreated = () => {
    const newScenario = createBus(scenario);
    setAndSaveScenario(newScenario);
  };

  const onBusDataChanged = (
    bus: string,
    field: string,
    newValue: string,
  ): ValidationError | null => {
    const [newScenario, err] = changeBusData(bus, field, newValue, scenario);
    if (err) {
      setToastMessage(err.message);
      return err;
    }
    setAndSaveScenario(newScenario);
    return null;
  };

  const onBusDeleted = (bus: string) => {
    const newScenario = deleteBus(bus, scenario);
    setAndSaveScenario(newScenario);
  };

  const onBusRenamed = (
    oldName: string,
    newName: string,
  ): ValidationError | null => {
    const [newScenario, err] = renameBus(oldName, newName, scenario);
    if (err) {
      setToastMessage(err.message);
      return err;
    }
    setAndSaveScenario(newScenario);
    return null;
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

  const onParameterChanged = (key: string, value: string) => {
    let newScenario, err;
    if (key === "Time horizon (h)") {
      [newScenario, err] = changeTimeHorizon(scenario, value);
    } else if (key === "Time step (min)") {
      [newScenario, err] = changeTimeStep(scenario, value);
    } else {
      [newScenario, err] = changeParameter(scenario, key, value);
    }
    if (err) {
      setToastMessage(err.message);
      return err;
    }
    setAndSaveScenario(newScenario);
    return null;
  };

  return (
    <div>
      <Header onClear={onClear} onSave={onSave} onLoad={onLoad} />
      <div className="content">
        <Parameters
          onParameterChanged={onParameterChanged}
          scenario={scenario}
        />
        <BusesComponent
          scenario={scenario}
          onBusCreated={onBusCreated}
          onBusDataChanged={onBusDataChanged}
          onBusRenamed={onBusRenamed}
          onBusDeleted={onBusDeleted}
          onDataChanged={onDataChanged}
        />
        <Toast message={toastMessage} />
      </div>
      <Footer />
    </div>
  );
};

export default CaseBuilder;
