/*
 * UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
 * Copyright (C) 2020-2025, UChicago Argonne, LLC. All rights reserved.
 * Released under the modified BSD license. See COPYING.md for more details.
 */

import { ReactNode } from "react";
import styles from "./Form.module.css";

function Form({ children }: { children: ReactNode }) {
  return <div className={styles.Form}>{children}</div>;
}

export default Form;
