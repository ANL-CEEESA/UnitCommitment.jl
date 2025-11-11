/*
 * UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
 * Copyright (C) 2020-2025, UChicago Argonne, LLC. All rights reserved.
 * Released under the modified BSD license. See COPYING.md for more details.
 */

import styles from "./SiteHeaderButton.module.css";

function SiteHeaderButton({
  title,
  onClick,
  variant = "light",
}: {
  title: string;
  onClick?: () => void;
  variant?: "light" | "primary";
}) {
  const variantClass = variant === "primary" ? styles.primary : styles.light;

  return (
    <button
      className={`${styles.SiteHeaderButton} ${variantClass}`}
      onClick={onClick}
    >
      {title}
    </button>
  );
}

export default SiteHeaderButton;
