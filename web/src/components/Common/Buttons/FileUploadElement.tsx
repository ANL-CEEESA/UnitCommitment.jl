/*
 * UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
 * Copyright (C) 2020-2025, UChicago Argonne, LLC. All rights reserved.
 * Released under the modified BSD license. See COPYING.md for more details.
 */

import React, {Component} from "react";

class FileUploadElement extends Component<any> {
    private inputRef = React.createRef<HTMLInputElement>();
    private callback: (data: any) => void = () => {};

    showFilePicker = (callback: (data: any) => void) => {
        this.callback = callback;
        this.inputRef.current?.click();
    };

    onFileSelected = (event: React.ChangeEvent<HTMLInputElement>) => {
        const file = event.target.files![0];
        if (file) {
            const reader = new FileReader();
            reader.onload = async (e) => {
                this.callback(e.target?.result as string);
                this.callback = () => {};
            };
            reader.readAsText(file);
        }
        event.target.value = '';
    };

    override render() {
        return <input
            ref={this.inputRef}
            type="file"
            accept={this.props.accept}
            style={{ display: "none" }}
            onChange={this.onFileSelected}
        />;
    }
}

export default FileUploadElement;