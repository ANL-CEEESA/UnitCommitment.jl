/*
 * UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
 * Copyright (C) 2020-2025, UChicago Argonne, LLC. All rights reserved.
 * Released under the modified BSD license. See COPYING.md for more details.
 */

import SectionHeader from "../../Common/SectionHeader/SectionHeader";
import Form from "../../Common/Forms/Form";
import TextInputRow from "../../Common/Forms/TextInputRow";
import { UnitCommitmentScenario } from "../../../core/fixtures";
import { ValidationError } from "../../../core/Validation/validate";

interface ParametersProps {
  scenario: UnitCommitmentScenario;
  onParameterChanged: (key: string, value: string) => ValidationError | null;
}

function Parameters(props: ParametersProps) {
  return (
    <div>
      <SectionHeader title="Parameters"></SectionHeader>
      <Form>
        <TextInputRow
          label="Time horizon"
          unit="h"
          tooltip="Length of the planning horizon (in hours)."
          initialValue={`${props.scenario.Parameters["Time horizon (h)"]}`}
          onChange={(v) => props.onParameterChanged("Time horizon (h)", v)}
        />
        <TextInputRow
          label="Time step"
          unit="min"
          tooltip="Length of each time step (in minutes). Must be a divisor of 60 (e.g. 60, 30, 20, 15, etc)."
          initialValue={`${props.scenario.Parameters["Time step (min)"]}`}
          onChange={(v) => props.onParameterChanged("Time step (min)", v)}
        />
        <TextInputRow
          label="Power balance penalty"
          unit="$/MW"
          tooltip="Penalty for system-wide shortage or surplus in production (in /MW). This is charged per time step. For example, if there is a shortage of 1 MW for three time steps, three times this amount will be charged."
          initialValue={`${props.scenario.Parameters["Power balance penalty ($/MW)"]}`}
          onChange={(v) =>
            props.onParameterChanged("Power balance penalty ($/MW)", v)
          }
        />
      </Form>
    </div>
  );
}

export default Parameters;
