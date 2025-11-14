/*
 * UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
 * Copyright (C) 2020-2025, UChicago Argonne, LLC. All rights reserved.
 * Released under the modified BSD license. See COPYING.md for more details.
 */

import styles from "../Common/Header.module.css";
import SiteHeaderButton from "../Common/Buttons/SiteHeaderButton";
import { useRef } from "react";
import FileUploadElement from "../Common/Buttons/FileUploadElement";
import { UnitCommitmentScenario } from "../../core/Data/types";
import { faDownload, faRotateLeft, faRotateRight, faTrash, faUpload } from "@fortawesome/free-solid-svg-icons";

interface HeaderProps {
  onClear: () => void;
  onSave: () => void;
  onUndo: () => void;
  onRedo: () => void;
  onLoad: (data: UnitCommitmentScenario) => void;
  onSolve: () => void;
  canUndo: boolean;
  canRedo: boolean;
}

function Header(props: HeaderProps) {
  const fileElem = useRef<FileUploadElement>(null);

  function onLoad() {
    fileElem.current!.showFilePicker((data: any) => {
      props.onLoad(data);
    });
  }

  return (
    <div className={styles.HeaderBox}>
      <div className={styles.HeaderContent}>
        <h1>UnitCommitment.jl</h1>
        <h2>Case Builder</h2>
        <div className={styles.buttonContainer}>
          <SiteHeaderButton title="Load" icon={faUpload} onClick={onLoad} />
          <SiteHeaderButton
            title="Save"
            icon={faDownload}
            onClick={props.onSave}
          />
          <SiteHeaderButton
            title="Undo"
            icon={faRotateLeft}
            onClick={props.onUndo}
            disabled={!props.canUndo}
          />
          <SiteHeaderButton
            title="Redo"
            icon={faRotateRight}
            onClick={props.onRedo}
            disabled={!props.canRedo}
          />
          <SiteHeaderButton
            title="Clear"
            icon={faTrash}
            onClick={props.onClear}
          />
          <SiteHeaderButton
            title="Solve"
            variant="primary"
            onClick={props.onSolve}
          />
        </div>
        <FileUploadElement ref={fileElem} accept=".json,.json.gz" />
      </div>
    </div>
  );
}

export default Header;
