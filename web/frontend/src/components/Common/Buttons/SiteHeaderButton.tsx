/*
 * UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
 * Copyright (C) 2020-2025, UChicago Argonne, LLC. All rights reserved.
 * Released under the modified BSD license. See COPYING.md for more details.
 */

import styles from "./SiteHeaderButton.module.css";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { IconDefinition } from "@fortawesome/fontawesome-svg-core";

function SiteHeaderButton({
  title,
  icon,
  onClick,
  variant = "light",
}: {
  title: string;
  icon: IconDefinition;
  onClick?: () => void;
  variant?: "light" | "primary";
}) {
  const variantClass = variant === "primary" ? styles.primary : styles.light;

  return (
    <button
      className={`${styles.SiteHeaderButton} ${variantClass}`}
      title={title}
      onClick={onClick}
    >
      <FontAwesomeIcon icon={icon} />
    </button>
  );
}

export default SiteHeaderButton;
