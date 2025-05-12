import styles from "./Header.module.css"
import Button from "../../Common/Buttons/Button";

function Header() {
    return (
        <div className={styles.HeaderBox}>
            <div className={styles.HeaderContent}>
                <h1>UnitCommitment.jl</h1>
                <h2>Case Builder</h2>
                <div className={styles.buttonContainer}>
                    <Button title="Clear"/>
                    <Button title="Load"/>
                    <Button title="Save"/>
                    <Button title="Submit"/>
                </div>
            </div>
        </div>
    );
}

export default Header;