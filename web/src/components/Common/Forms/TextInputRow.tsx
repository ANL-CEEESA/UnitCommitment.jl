import formStyles from "./Form.module.css";
import HelpButton from "./HelpButton";

function TextInputRow({label, unit, tooltip, currentValue, defaultValue}: {
    label: string,
    unit: string,
    tooltip: string,
    currentValue: string,
    defaultValue: string,
}) {
    return (
        <div className={formStyles.FormRow}>
            <label>
                {label}
                <span className={formStyles.FormRow_unit}> ({unit})</span>
            </label>
            <input
                type="text"
                placeholder={defaultValue}
                value={currentValue}
            />
            <HelpButton text={tooltip} />
        </div>
    )
}

export default TextInputRow;