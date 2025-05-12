import { ReactNode } from 'react';
import styles from "./Form.module.css"

function Form({ children }: { children: ReactNode }) {
    return <div className={styles.Form}>{children}</div>
}

export default Form;