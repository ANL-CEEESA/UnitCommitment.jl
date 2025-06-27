/*
 * UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
 * Copyright (C) 2020-2025, UChicago Argonne, LLC. All rights reserved.
 * Released under the modified BSD license. See COPYING.md for more details.
 */

import styles from "./HelpButton.module.css";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { faCircleQuestion } from "@fortawesome/free-regular-svg-icons";

function HelpButton({ text }: { text: String }) {
  return (
    <button className={styles.HelpButton}>
      <span className={styles.tooltip}>{text}</span>
      <span className={styles.icon}>
        <FontAwesomeIcon icon={faCircleQuestion} />
      </span>
    </button>
  );
}

export default HelpButton;
