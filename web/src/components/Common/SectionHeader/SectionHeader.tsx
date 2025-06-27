/*
 * UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
 * Copyright (C) 2020-2025, UChicago Argonne, LLC. All rights reserved.
 * Released under the modified BSD license. See COPYING.md for more details.
 */

import styles from "./SectionHeader.module.css";
import { ReactNode } from "react";

interface SectionHeaderProps {
  title: string;
  children?: ReactNode;
}

function SectionHeader({ title, children }: SectionHeaderProps) {
  return (
    <div className={styles.SectionHeader}>
      <div className={styles.SectionButtonsContainer}>{children}</div>
      <h1>{title}</h1>
    </div>
  );
}

export default SectionHeader;
