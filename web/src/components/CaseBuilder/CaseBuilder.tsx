/*
 * UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
 * Copyright (C) 2020-2025, UChicago Argonne, LLC. All rights reserved.
 * Released under the modified BSD license. See COPYING.md for more details.
 */

import Header from "./Header/Header";
import Parameters from "./Parameters/Parameters";
import BusesComponent from "./Buses/BusesComponent";
import {
  BLANK_SCENARIO,
  TEST_SCENARIO,
  UnitCommitmentScenario,
} from "../../core/data";

import "tabulator-tables/dist/css/tabulator.min.css";
import "../Common/Forms/Tables.css";
import { useState } from "react";
import Footer from "./Footer/Footer";
import { validate, ValidationError } from "../../core/Validation/validate";
import { offerDownload } from "../Common/io";
import {
  changeBusData,
  createBus,
  deleteBus,
  renameBus,
} from "./Buses/BusOperations";

const CaseBuilder = () => {
  const [scenario, setScenario] = useState(TEST_SCENARIO);

  const onClear = () => {
    setScenario(BLANK_SCENARIO);
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
    setScenario(newScenario);
  };

  const onBusDataChanged = (
    bus: string,
    field: string,
    newValue: string,
  ): ValidationError | null => {
    const [newScenario, err] = changeBusData(bus, field, newValue, scenario);
    if (err) {
      console.log(err);
      return err;
    }
    setScenario(newScenario);
    return null;
  };

  const onBusDeleted = (bus: string) => {
    const newScenario = deleteBus(bus, scenario);
    setScenario(newScenario);
  };

  const onBusRenamed = (
    oldName: string,
    newName: string,
  ): ValidationError | null => {
    const [newScenario, err] = renameBus(oldName, newName, scenario);
    if (err) {
      console.log(err);
      return err;
    }
    setScenario(newScenario);
    return null;
  };

  const onDataChanged = (newScenario: UnitCommitmentScenario) => {
    setScenario(newScenario);
  };

  const onLoad = (scenario: UnitCommitmentScenario) => {
    if (!validate(scenario)) {
      console.error(validate.errors);
      return;
    }
    setScenario(scenario);
  };

  return (
    <div>
      <Header onClear={onClear} onSave={onSave} onLoad={onLoad} />
      <div className="content">
        <Parameters scenario={scenario} />
        <BusesComponent
          scenario={scenario}
          onBusCreated={onBusCreated}
          onBusDataChanged={onBusDataChanged}
          onBusRenamed={onBusRenamed}
          onBusDeleted={onBusDeleted}
          onDataChanged={onDataChanged}
        />
      </div>
      <Footer />
    </div>
  );
};

export default CaseBuilder;
