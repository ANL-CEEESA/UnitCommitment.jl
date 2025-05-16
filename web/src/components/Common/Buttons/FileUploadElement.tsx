/*
 * UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
 * Copyright (C) 2020-2025, UChicago Argonne, LLC. All rights reserved.
 * Released under the modified BSD license. See COPYING.md for more details.
 */

import pako from "pako";
import React, { Component } from "react";

class FileUploadElement extends Component<any> {
  private inputRef = React.createRef<HTMLInputElement>();
  private callback: (data: any) => void = () => {};

  showFilePicker = (callback: (data: any) => void) => {
    this.callback = callback;
    this.inputRef.current?.click();
  };

  onFileSelected = (event: React.ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files![0]!;
    let isCompressed = file.name.endsWith(".gz");
    if (file) {
      const reader = new FileReader();
      reader.onload = async (e) => {
        let content = e.target?.result;

        if (isCompressed) {
          const compressed = new Uint8Array(content as ArrayBuffer);
          const decompressed = pako.inflate(compressed);
          content = new TextDecoder().decode(decompressed);
        }

        this.callback(content as string);
        this.callback = () => {};
      };
      if (isCompressed) {
        reader.readAsArrayBuffer(file);
      } else {
        reader.readAsText(file);
      }
    }
    event.target.value = "";
  };

  override render() {
    return (
      <input
        ref={this.inputRef}
        type="file"
        accept={this.props.accept}
        style={{ display: "none" }}
        onChange={this.onFileSelected}
      />
    );
  }
}

export default FileUploadElement;
