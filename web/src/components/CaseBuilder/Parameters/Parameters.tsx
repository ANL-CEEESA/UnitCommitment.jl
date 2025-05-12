import SectionHeader from "../../Common/SectionHeader/SectionHeader";
import Form from "../../Common/Forms/Form";
import TextInputRow from "../../Common/Forms/TextInputRow";

function Parameters() {
    return (
        <div>
            <SectionHeader title="Parameters" />
            <Form>
                <TextInputRow
                    label="Time horizon"
                    unit="h"
                    tooltip="Length of the planning horizon (in hours)."
                    currentValue="48"
                    defaultValue="24"
                />
                <TextInputRow
                    label="Time step"
                    unit="min"
                    tooltip="Length of each time step (in minutes). Must be a divisor of 60 (e.g. 60, 30, 20, 15, etc)."
                    currentValue=""
                    defaultValue="60"
                />
                <TextInputRow
                    label="Power balance penalty"
                    unit="$/MW"
                    tooltip="Penalty for system-wide shortage or surplus in production (in /MW). This is charged per time step. For example, if there is a shortage of 1 MW for three time steps, three times this amount will be charged."
                    currentValue=""
                    defaultValue="1000.0"
                />
            </Form>
        </div>
    )
}

export default Parameters;