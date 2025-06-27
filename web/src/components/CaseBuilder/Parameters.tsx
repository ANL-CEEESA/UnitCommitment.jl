/*
 * UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
 * Copyright (C) 2020-2025, UChicago Argonne, LLC. All rights reserved.
 * Released under the modified BSD license. See COPYING.md for more details.
 */

import SectionHeader from "../Common/SectionHeader/SectionHeader";
import Form from "../Common/Forms/Form";
import TextInputRow from "../Common/Forms/TextInputRow";
import {
  changeParameter,
  changeTimeHorizon,
  changeTimeStep,
} from "../../core/Operations/parameterOps";
import { UnitCommitmentScenario } from "../../core/Data/types";

interface ParametersProps {
  scenario: UnitCommitmentScenario;
  onError: (msg: string) => void;
  onDataChanged: (scenario: UnitCommitmentScenario) => void;
}

function Parameters(props: ParametersProps) {
  const onDataChanged = (key: string, value: string) => {
    let newScenario, err;
    if (key === "Time horizon (h)") {
      [newScenario, err] = changeTimeHorizon(props.scenario, value);
    } else if (key === "Time step (min)") {
      [newScenario, err] = changeTimeStep(props.scenario, value);
    } else {
      [newScenario, err] = changeParameter(props.scenario, key, value);
    }
    if (err) {
      props.onError(err.message);
      return err;
    }
    props.onDataChanged(newScenario);
    return null;
  };

  return (
    <div>
      <SectionHeader title="Parameters"></SectionHeader>
      <Form>
        <TextInputRow
          label="Time horizon"
          unit="h"
          tooltip="Length of the planning horizon (in hours)."
          initialValue={`${props.scenario.Parameters["Time horizon (h)"]}`}
          onChange={(v) => onDataChanged("Time horizon (h)", v)}
        />
        <TextInputRow
          label="Time step"
          unit="min"
          tooltip="Length of each time step (in minutes). Must be a divisor of 60 (e.g. 60, 30, 20, 15, etc)."
          initialValue={`${props.scenario.Parameters["Time step (min)"]}`}
          onChange={(v) => onDataChanged("Time step (min)", v)}
        />
        <TextInputRow
          label="Power balance penalty"
          unit="$/MW"
          tooltip="Penalty for system-wide shortage or surplus in production (in /MW). This is charged per time step. For example, if there is a shortage of 1 MW for three time steps, three times this amount will be charged."
          initialValue={`${props.scenario.Parameters["Power balance penalty ($/MW)"]}`}
          onChange={(v) => onDataChanged("Power balance penalty ($/MW)", v)}
        />
      </Form>
    </div>
  );
}

export default Parameters;
