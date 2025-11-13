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
  disabled = false,
}: {
  title: string;
  icon: IconDefinition;
  onClick?: () => void;
  variant?: "light" | "primary";
  disabled?: boolean;
}) {
  const variantClass = variant === "primary" ? styles.primary : styles.light;
  const disabledClass = disabled ? styles.disabled : "";

  return (
    <button
      className={`${styles.SiteHeaderButton} ${variantClass} ${disabledClass}`}
      title={title}
      onClick={onClick}
      disabled={disabled}
    >
      <FontAwesomeIcon icon={icon} />
    </button>
  );
}

export default SiteHeaderButton;
