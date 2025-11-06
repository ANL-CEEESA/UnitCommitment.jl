/*
 * UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
 * Copyright (C) 2020-2025, UChicago Argonne, LLC. All rights reserved.
 * Released under the modified BSD license. See COPYING.md for more details.
 */

import styles from "./Toast.module.css";
import { useEffect, useState } from "react";

interface ToastProps {
  message: string;
}

const Toast = (props: ToastProps) => {
  const [isVisible, setVisible] = useState(true);

  useEffect(() => {
    if (props.message.length === 0) return;
    setVisible(true);
    const timer = setTimeout(() => {
      setVisible(false);
    }, 5000);
    return () => clearTimeout(timer);
  }, [props.message]);

  return (
    <div>
      <div className={styles.Toast} style={{ opacity: isVisible ? 1 : 0 }}>
        {props.message}
      </div>
    </div>
  );
};

export default Toast;
