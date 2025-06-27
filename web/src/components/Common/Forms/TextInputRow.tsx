/*
 * UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
 * Copyright (C) 2020-2025, UChicago Argonne, LLC. All rights reserved.
 * Released under the modified BSD license. See COPYING.md for more details.
 */

import formStyles from "./Form.module.css";
import HelpButton from "../Buttons/HelpButton";
import React, { useRef, useState } from "react";
import { ValidationError } from "../../../core/Data/validate";

interface TextInputRowProps {
  label: string;
  unit: string;
  tooltip: string;
  initialValue: string;
  onChange: (newValue: string) => ValidationError | null;
}

function TextInputRow(props: TextInputRowProps) {
  const [savedValue, setSavedValue] = useState(props.initialValue);
  const inputRef = useRef<HTMLInputElement>(null);

  const onBlur = (event: React.FocusEvent<HTMLInputElement>) => {
    const newValue = event.target.value;
    if (newValue === savedValue) return;
    const err = props.onChange(newValue);
    if (err) {
      inputRef.current!.value = savedValue;
      return;
    }
    setSavedValue(newValue);
  };
  return (
    <div className={formStyles.FormRow}>
      <label>
        {props.label}
        <span className={formStyles.FormRow_unit}> ({props.unit})</span>
      </label>
      <input
        ref={inputRef}
        type="text"
        defaultValue={savedValue}
        onBlur={onBlur}
      />
      <HelpButton text={props.tooltip} />
    </div>
  );
}

export default TextInputRow;
