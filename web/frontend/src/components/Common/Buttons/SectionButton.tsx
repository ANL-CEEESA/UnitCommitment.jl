/*
 * UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
 * Copyright (C) 2020-2025, UChicago Argonne, LLC. All rights reserved.
 * Released under the modified BSD license. See COPYING.md for more details.
 */

import { IconDefinition } from "@fortawesome/fontawesome-svg-core";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import styles from "./SectionButton.module.css";

interface SectionButtonProps {
  icon: IconDefinition;
  tooltip: string;
  onClick?: () => void;
}

function SectionButton(props: SectionButtonProps) {
  return (
    <button
      className={styles.SectionButton}
      title={props.tooltip}
      onClick={props.onClick}
    >
      <FontAwesomeIcon icon={props.icon} />
    </button>
  );
}

export default SectionButton;
